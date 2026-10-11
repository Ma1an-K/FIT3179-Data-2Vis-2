#!/usr/bin/env bash
# Exports the three Best Film CSVs from Wikidata. Run from the repo root.
set -euo pipefail
UA="FIT3179-student-project/0.1 (contact: info@ormada.com.au)"
# Retries up to 3 times (sleep 15 between) because the endpoint sometimes returns 504/timeouts.
Q() {
  local n out
  for n in 1 2 3 4; do
    if out=$(curl -sS --fail -G 'https://query.wikidata.org/sparql' -H "Accept: text/csv" -A "$UA" --data-urlencode "query=$1"); then
      printf '%s\n' "$out"; return 0
    fi
    if [ "$n" -lt 4 ]; then echo "query failed (attempt $n), retrying in 15 s" >&2; sleep 15; fi
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

# 1b. Winners missing from Wikidata: appended from data/manual_winners.csv (source_url dropped; film_qid empty).
python3 - <<'PY'
import csv
rows = list(csv.reader(open("data/manual_winners.csv", newline="")))[1:]
with open("data/best_film_winners.csv", "a", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    for r in rows: w.writerow(r[:4])
PY

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

# 2b. Derived: one setting classification per winner (used by the waffle chart).
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
        w.writerow([f_, r["year"], "Not recorded" if f_ not in setting else ("Set in Australia" if setting[f_] else "Set overseas")])
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

wc -l data/best_film_*.csv
