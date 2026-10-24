#!/usr/bin/env bash
# Exports the Best Film CSVs from Wikidata. Run from the repo root.
set -euo pipefail
UA="FIT3179-student-project/0.1 (Monash University coursework)"
# Makes up to 3 attempts in total (sleep 15 between) because the endpoint sometimes returns 504/timeouts.
Q() {
  local n out
  for n in 1 2 3; do
    if out=$(curl -sS --fail -G 'https://query.wikidata.org/sparql' -H "Accept: text/csv" -A "$UA" --data-urlencode "query=$1"); then
      printf '%s\n' "$out"; return 0
    fi
    if [ "$n" -lt 3 ]; then echo "query failed (attempt $n), retrying in 15 s" >&2; sleep 15; fi
  done
  return 1
}

# 1. Winners: one row per film (films only; producers who also hold the award are excluded).
Q 'SELECT ?film_qid ?film (MIN(?y) AS ?year) (GROUP_CONCAT(DISTINCT ?dirLabel; separator="; ") AS ?director) WHERE {
  ?film_qid p:P166 ?st . ?st ps:P166 wd:Q3600406 .
  ?film_qid wdt:P31/wdt:P279* wd:Q11424 .
  OPTIONAL { ?st pq:P585 ?t } OPTIONAL { ?film_qid wdt:P577 ?pub }
  BIND(YEAR(COALESCE(?t,?pub)) AS ?y)
  ?film_qid rdfs:label ?film FILTER(LANG(?film)="en")
  OPTIONAL { ?film_qid wdt:P57 ?dir . ?dir rdfs:label ?dirLabel FILTER(LANG(?dirLabel)="en") }
} GROUP BY ?film_qid ?film ORDER BY ?year' > data/best_film_winners.csv

# 1b. Winners whose award link is missing on Wikidata: appended from data/manual_winners.csv (source_url dropped).
#     These films are queried by QID in steps 2c, 3c and 4c below.
python3 - <<'PY'
import csv
rows = list(csv.reader(open("data/manual_winners.csv", newline="")))[1:]
with open("data/best_film_winners.csv", "a", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    for r in rows: w.writerow(r[:4])
PY

# Helpers for the manual films (steps 2c, 3c, 4c). The award-linked queries 2-4 stay unchanged; a UNION of
# both film sets timed out on the endpoint, so the 12 manual films are queried separately by QID.
# MANUAL_VALUES: the film_qid column of manual_winners.csv as a SPARQL VALUES list.
MANUAL_VALUES=$(python3 -c '
import csv
print(" ".join("wd:" + r["film_qid"].rsplit("/", 1)[1] for r in csv.DictReader(open("data/manual_winners.csv", newline=""))))
')
# append_manual TARGET [COLUMN]: reads a query result (first column ?f = film QID URI) on stdin, takes film name and year
# from manual_winners.csv by film_qid, and appends rows to TARGET in TARGET's own column order. With COLUMN,
# rows where that column is empty (no coordinates) are dropped.
append_manual() {
  python3 -c '
import csv, sys
target = sys.argv[1]
manual = {r["film_qid"]: r for r in csv.DictReader(open("data/manual_winners.csv", newline=""))}
header = open(target, newline="").readline().strip().split(",")
rows = list(csv.DictReader(sys.stdin))
if len(sys.argv) > 2: rows = [r for r in rows if r[sys.argv[2]]]
with open(target, "a", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    for r in rows:
        m = manual[r["f"]]
        r["film"], r["year"] = m["film"], m["year"]
        w.writerow([r[h] for h in header])
print(target, "+", len(rows), "manual-film rows", file=sys.stderr)
' "$@"
}

# 2. Locations: story settings (P840) and filming locations (P915) with coordinates.
#    Country-level places (where the place IS the country) are kept but flagged level=country: they only have a
#    centroid, so the map ignores them while the waffle (best_film_settings.csv) still counts them.
#    (The brief's version joined rdfs:label on ?p and timed out on the endpoint (60 s limit); the
#    place/country labels now come from the label service after a fast inner select. Same columns.)
Q 'SELECT DISTINCT ?film ?year ?kind ?place ?country ?lon ?lat ?level WHERE {
  { SELECT ?film ?year ?kind ?p ?coord WHERE {
    ?f p:P166 ?st . ?st ps:P166 wd:Q3600406 . ?f wdt:P31/wdt:P279* wd:Q11424 .
    OPTIONAL { ?st pq:P585 ?t } OPTIONAL { ?f wdt:P577 ?pub } BIND(YEAR(COALESCE(?t,?pub)) AS ?year)
    ?f rdfs:label ?film FILTER(LANG(?film)="en")
    { ?f wdt:P840 ?p . BIND("setting" AS ?kind) } UNION { ?f wdt:P915 ?p . BIND("filming" AS ?kind) }
    ?p wdt:P625 ?coord .
  } }
  BIND(IF(EXISTS { ?p wdt:P31 wd:Q6256 }, "country", "place") AS ?level)
  BIND(geof:longitude(?coord) AS ?lon) BIND(geof:latitude(?coord) AS ?lat)
  OPTIONAL { ?p wdt:P17 ?c }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . ?p rdfs:label ?place . ?c rdfs:label ?country . }
} ORDER BY ?year ?film'> data/best_film_locations.csv

# 2c. Locations for the manual films (same columns as query 2; year from the CSV). Coordinates are OPTIONAL in
#     the query (a required ?p wdt:P625 made the endpoint time out) and rows without them are dropped in Python,
#     so the result matches query 2's coordinate requirement.
Q 'SELECT DISTINCT ?f ?kind ?place ?country ?lon ?lat ?level WHERE {
  VALUES ?f { '"$MANUAL_VALUES"' }
  { ?f wdt:P840 ?p . BIND("setting" AS ?kind) } UNION { ?f wdt:P915 ?p . BIND("filming" AS ?kind) }
  OPTIONAL { ?p wdt:P625 ?coord . BIND(geof:longitude(?coord) AS ?lon) BIND(geof:latitude(?coord) AS ?lat) }
  OPTIONAL { ?p wdt:P17 ?c }
  BIND(IF(EXISTS { ?p wdt:P31 wd:Q6256 }, "country", "place") AS ?level)
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . ?p rdfs:label ?place . ?c rdfs:label ?country . }
}' | append_manual data/best_film_locations.csv lon

# 2b. Derived (after 2c, so the manual films are included): one setting classification per winner (waffle chart).
python3 - <<'PY'
import csv
setting = {}
for r in csv.DictReader(open("data/best_film_locations.csv", newline="")):
    if r["kind"] != "setting": continue
    aus = r["country"] == "Australia" or r["place"] == "Australia"
    setting[r["film"]] = setting.get(r["film"], False) or aus
with open("data/best_film_settings.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["film", "year", "setting"])
    for r in csv.DictReader(open("data/best_film_winners.csv", newline="")):
        f_ = r["film"]
        w.writerow([f_, r["year"], "No setting data" if f_ not in setting else ("Set in Australia" if setting[f_] else "Set overseas")])
PY

# 3. Directors with birthplace coordinates.
Q 'SELECT ?director ?film ?year (SAMPLE(?bp) AS ?birthplace) (SAMPLE(?bc) AS ?birth_country) (SAMPLE(?lo) AS ?lon) (SAMPLE(?la) AS ?lat) WHERE {
  ?f p:P166 ?st . ?st ps:P166 wd:Q3600406 . ?f wdt:P31/wdt:P279* wd:Q11424 .
  OPTIONAL { ?st pq:P585 ?t } OPTIONAL { ?f wdt:P577 ?pub } BIND(YEAR(COALESCE(?t,?pub)) AS ?year)
  ?f rdfs:label ?film FILTER(LANG(?film)="en")
  ?f wdt:P57 ?d . ?d rdfs:label ?director FILTER(LANG(?director)="en")
  OPTIONAL { ?d wdt:P19 ?b . ?b wdt:P625 ?coord . ?b rdfs:label ?bp FILTER(LANG(?bp)="en")
    FILTER NOT EXISTS { ?b wdt:P31 wd:Q6256 } FILTER NOT EXISTS { ?b wdt:P31 wd:Q3336843 }
    OPTIONAL { ?b wdt:P17 ?c . ?c rdfs:label ?bc FILTER(LANG(?bc)="en") }
    BIND(geof:longitude(?coord) AS ?lo) BIND(geof:latitude(?coord) AS ?la) }
} GROUP BY ?director ?film ?year ORDER BY ?year'> data/best_film_directors.csv

# 3c. Directors of the manual films (same columns and exclusions as query 3; year from the CSV; rows without
#     birthplace coordinates dropped).
Q 'SELECT ?f ?director (SAMPLE(?bp) AS ?birthplace) (SAMPLE(?bc) AS ?birth_country) (SAMPLE(?lo) AS ?lon) (SAMPLE(?la) AS ?lat) WHERE {
  VALUES ?f { '"$MANUAL_VALUES"' }
  ?f wdt:P57 ?d . ?d rdfs:label ?director FILTER(LANG(?director)="en")
  OPTIONAL { ?d wdt:P19 ?b . ?b wdt:P625 ?coord . ?b rdfs:label ?bp FILTER(LANG(?bp)="en")
    FILTER NOT EXISTS { ?b wdt:P31 wd:Q6256 } FILTER NOT EXISTS { ?b wdt:P31 wd:Q3336843 }
    OPTIONAL { ?b wdt:P17 ?c . ?c rdfs:label ?bc FILTER(LANG(?bc)="en") }
    BIND(geof:longitude(?coord) AS ?lo) BIND(geof:latitude(?coord) AS ?la) }
} GROUP BY ?f ?director' | append_manual data/best_film_directors.csv lon

# 4. Flows: director birthplace -> a recorded narrative location of the winning film. Country-level settings are
#    excluded (they only have a centroid), so a film set only in a whole country has no flow.
Q 'SELECT ?director ?film ?year (SAMPLE(?bp) AS ?birthplace) (SAMPLE(?bc) AS ?birth_country) (SAMPLE(?lon1) AS ?lon1) (SAMPLE(?lat1) AS ?lat1) (SAMPLE(?setting) AS ?setting) (SAMPLE(?lon2) AS ?lon2) (SAMPLE(?lat2) AS ?lat2) WHERE {
  ?f p:P166 ?st . ?st ps:P166 wd:Q3600406 . ?f wdt:P31/wdt:P279* wd:Q11424 .
  OPTIONAL { ?st pq:P585 ?t } OPTIONAL { ?f wdt:P577 ?pub } BIND(YEAR(COALESCE(?t,?pub)) AS ?year)
  ?f rdfs:label ?film FILTER(LANG(?film)="en")
  ?f wdt:P57 ?d . ?d rdfs:label ?director FILTER(LANG(?director)="en")
  ?d wdt:P19 ?b . ?b wdt:P625 ?c1 .
  FILTER NOT EXISTS { ?b wdt:P31 wd:Q6256 } FILTER NOT EXISTS { ?b wdt:P31 wd:Q3336843 }
  ?b rdfs:label ?bp FILTER(LANG(?bp)="en")
  OPTIONAL { ?b wdt:P17 ?c . ?c rdfs:label ?bc FILTER(LANG(?bc)="en") }
  BIND(geof:longitude(?c1) AS ?lon1) BIND(geof:latitude(?c1) AS ?lat1)
  ?f wdt:P840 ?p . ?p wdt:P625 ?c2 . ?p rdfs:label ?setting FILTER(LANG(?setting)="en")
  FILTER NOT EXISTS { ?p wdt:P31 wd:Q6256 }
  BIND(geof:longitude(?c2) AS ?lon2) BIND(geof:latitude(?c2) AS ?lat2)
} GROUP BY ?director ?film ?year ORDER BY ?year' > data/flows.csv

# 4c. Flows for the manual films (same columns and exclusions as query 4; year from the CSV).
Q 'SELECT ?f ?director (SAMPLE(?bp) AS ?birthplace) (SAMPLE(?bc) AS ?birth_country) (SAMPLE(?lon1) AS ?lon1) (SAMPLE(?lat1) AS ?lat1) (SAMPLE(?setting) AS ?setting) (SAMPLE(?lon2) AS ?lon2) (SAMPLE(?lat2) AS ?lat2) WHERE {
  VALUES ?f { '"$MANUAL_VALUES"' }
  ?f wdt:P57 ?d . ?d rdfs:label ?director FILTER(LANG(?director)="en")
  ?d wdt:P19 ?b . ?b wdt:P625 ?c1 .
  FILTER NOT EXISTS { ?b wdt:P31 wd:Q6256 } FILTER NOT EXISTS { ?b wdt:P31 wd:Q3336843 }
  ?b rdfs:label ?bp FILTER(LANG(?bp)="en")
  OPTIONAL { ?b wdt:P17 ?c . ?c rdfs:label ?bc FILTER(LANG(?bc)="en") }
  BIND(geof:longitude(?c1) AS ?lon1) BIND(geof:latitude(?c1) AS ?lat1)
  ?f wdt:P840 ?p . ?p wdt:P625 ?c2 . ?p rdfs:label ?setting FILTER(LANG(?setting)="en")
  FILTER NOT EXISTS { ?p wdt:P31 wd:Q6256 }
  BIND(geof:longitude(?c2) AS ?lon2) BIND(geof:latitude(?c2) AS ?lat2)
} GROUP BY ?f ?director' | append_manual data/flows.csv

# All 58 winners by QID (award-linked + manual), for the film-level queries below.
ALL_VALUES=$(python3 -c '
import csv
print(" ".join("wd:" + r["film_qid"].rsplit("/", 1)[-1] for r in csv.DictReader(open("data/best_film_winners.csv"))))')

# 5. Genres (P136), one row per film x genre; genre_group keeps the 8 most common genres and folds the rest into Other.
Q 'SELECT ?f ?genre WHERE {
  VALUES ?f { '"$ALL_VALUES"' }
  ?f wdt:P136 ?g . ?g rdfs:label ?genre FILTER(LANG(?genre)="en")
}' > data/_genres_raw.csv
python3 - <<'PY'
import csv, collections
win = {r["film_qid"]: r for r in csv.DictReader(open("data/best_film_winners.csv", newline=""))}
rows = [r for r in csv.DictReader(open("data/_genres_raw.csv", newline=""))]
by_genre = collections.Counter(r["genre"] for r in rows)
top8 = [g for g, _ in by_genre.most_common(8)]
pretty = lambda g: g.replace(" film", "").capitalize() if g.endswith(" film") else g.capitalize()
with open("data/best_film_genres.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["film", "year", "genre", "genre_group"])
    for r in sorted(rows, key=lambda r: (int(win[r["f"]]["year"]), win[r["f"]]["film"], r["genre"])):
        w.writerow([win[r["f"]]["film"], win[r["f"]]["year"], pretty(r["genre"]), pretty(r["genre"]) if r["genre"] in top8 else "Other"])
PY
rm data/_genres_raw.csv

# 6. Film facts: credited cast size (distinct P161) and runtime in minutes (P2047, minimum if several).
Q 'SELECT ?f (COUNT(DISTINCT ?a) AS ?cast_size) (MIN(?rt) AS ?runtime_min) WHERE {
  VALUES ?f { '"$ALL_VALUES"' }
  OPTIONAL { ?f wdt:P161 ?a }
  OPTIONAL { ?f wdt:P2047 ?rt }
} GROUP BY ?f' > data/_facts_raw.csv
python3 - <<'PY'
import csv
win = {r["film_qid"]: r for r in csv.DictReader(open("data/best_film_winners.csv", newline=""))}
raw = {r["f"]: r for r in csv.DictReader(open("data/_facts_raw.csv", newline=""))}
with open("data/best_film_facts.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["film", "year", "cast_size", "runtime_min"])
    for q, r in sorted(win.items(), key=lambda kv: (int(kv[1]["year"]), kv[1]["film"])):
        x = raw.get(q, {})
        rt = x.get("runtime_min", "")
        w.writerow([r["film"], r["year"], x.get("cast_size", "0"), str(int(float(rt))) if rt else ""])
PY
rm data/_facts_raw.csv

# 7. Director careers: films directed on Wikidata (any film item with P57 = director) vs Best Film wins among the 58.
Q 'SELECT ?director (COUNT(DISTINCT ?x) AS ?films_directed) (COUNT(DISTINCT ?f) AS ?best_film_wins) WHERE {
  VALUES ?f { '"$ALL_VALUES"' }
  ?f wdt:P57 ?d . ?d rdfs:label ?director FILTER(LANG(?director)="en")
  ?x wdt:P57 ?d . ?x wdt:P31/wdt:P279* wd:Q11424 .
} GROUP BY ?director ORDER BY DESC(?films_directed)' > data/_careers_raw.csv
python3 - <<'PY'
import csv
win = list(csv.DictReader(open("data/best_film_winners.csv", newline="")))
years = {}
for r in win:
    for d in r["director"].split("; "):
        if d: years.setdefault(d, []).append(int(r["year"]))
with open("data/director_careers.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["director", "films_directed", "best_film_wins", "first_win", "last_win"])
    for r in csv.DictReader(open("data/_careers_raw.csv", newline="")):
        ys = years.get(r["director"], [])
        w.writerow([r["director"], r["films_directed"], r["best_film_wins"], min(ys) if ys else "", max(ys) if ys else ""])
PY
rm data/_careers_raw.csv

# 8. Oscar comparison: Academy Award for Best Picture (Q102427) winners, one row per film. P585 on the award statement is
#    the ceremony date, so year = ceremony year - 1 (the film year honoured, matching the AACTA year). Honoured years
#    1969-2025. Producers who hold the award are dropped by the film-class filter. Labels fall back to "mul" (Forrest
#    Gump has no "en" label). Runtime: best-rank P2047 values converted to minutes (some are stored in seconds,
#    Q11574), shortest if several (same rule as best_film_facts.csv), rounded to the minute.
Q 'SELECT ?f (SAMPLE(?lbl) AS ?film) (YEAR(MIN(?t)) - 1 AS ?year) (GROUP_CONCAT(DISTINCT CONCAT(STR(?amt), " ", STRAFTER(STR(?unit), "entity/")); separator="|") AS ?runtimes) WHERE {
  ?f p:P166 ?st . ?st ps:P166 wd:Q102427 ; pq:P585 ?t .
  ?f wdt:P31/wdt:P279* wd:Q11424 .
  ?f rdfs:label ?lbl FILTER(LANG(?lbl) IN ("en", "mul"))
  OPTIONAL { ?f p:P2047 ?rs . ?rs a wikibase:BestRank ; psv:P2047 [ wikibase:quantityAmount ?amt ; wikibase:quantityUnit ?unit ] }
} GROUP BY ?f HAVING (YEAR(MIN(?t)) - 1 >= 1969 && YEAR(MIN(?t)) - 1 <= 2025) ORDER BY ?year' > data/_oscar_raw.csv
python3 - <<'PY'
import csv
TO_MIN = {"Q7727": 1, "Q11574": 1 / 60}  # minute, second
with open("data/oscar_best_picture.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["film", "year", "runtime_min"])
    for r in csv.DictReader(open("data/_oscar_raw.csv", newline="")):
        vals = [float(a) * TO_MIN[u] for a, u in (x.split(" ") for x in r["runtimes"].split("|") if x)]
        w.writerow([r["film"], r["year"], str(round(min(vals))) if vals else ""])
PY
rm data/_oscar_raw.csv

wc -l data/best_film_*.csv data/flows.csv data/oscar_best_picture.csv
