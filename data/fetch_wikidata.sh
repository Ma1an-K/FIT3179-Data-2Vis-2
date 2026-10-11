#!/usr/bin/env bash
# Exports the three Best Film CSVs from Wikidata. Run from the repo root.
set -euo pipefail
UA="FIT3179-student-project/0.1 (contact: info@ormada.com.au)"
Q() { curl -s -G 'https://query.wikidata.org/sparql' -H "Accept: text/csv" -A "$UA" --data-urlencode "query=$1"; }

# 1. Winners: one row per film (films only; producers who also hold the award are excluded).
Q 'SELECT ?film_qid ?film (MIN(?y) AS ?year) (GROUP_CONCAT(DISTINCT ?dirLabel; separator="; ") AS ?director) WHERE {
  ?film_qid p:P166 ?st . ?st ps:P166 wd:Q3600406 .
  ?film_qid wdt:P31/wdt:P279* wd:Q11424 .
  OPTIONAL { ?st pq:P585 ?t } OPTIONAL { ?film_qid wdt:P577 ?pub }
  BIND(YEAR(COALESCE(?t,?pub)) AS ?y)
  ?film_qid rdfs:label ?film FILTER(LANG(?film)="en")
  OPTIONAL { ?film_qid wdt:P57 ?dir . ?dir rdfs:label ?dirLabel FILTER(LANG(?dirLabel)="en") }
} GROUP BY ?film_qid ?film ORDER BY ?year' > data/best_film_winners.csv

# 2. Locations: story settings (P840) and filming locations (P915) with coordinates.
#    Country-level places (where the place IS the country) are dropped: they only have a centroid.
#    (The brief's version joined rdfs:label on ?p and timed out on the endpoint (60 s limit); the
#    place/country labels now come from the label service after a fast inner select. Same columns.)
Q 'SELECT DISTINCT ?film ?year ?kind ?place ?country ?lon ?lat WHERE {
  { SELECT ?film ?year ?kind ?p ?coord WHERE {
    ?f p:P166 ?st . ?st ps:P166 wd:Q3600406 . ?f wdt:P31/wdt:P279* wd:Q11424 .
    OPTIONAL { ?st pq:P585 ?t } OPTIONAL { ?f wdt:P577 ?pub } BIND(YEAR(COALESCE(?t,?pub)) AS ?year)
    ?f rdfs:label ?film FILTER(LANG(?film)="en")
    { ?f wdt:P840 ?p . BIND("setting" AS ?kind) } UNION { ?f wdt:P915 ?p . BIND("filming" AS ?kind) }
    ?p wdt:P625 ?coord .
  } }
  FILTER NOT EXISTS { ?p wdt:P31 wd:Q6256 }
  BIND(geof:longitude(?coord) AS ?lon) BIND(geof:latitude(?coord) AS ?lat)
  OPTIONAL { ?p wdt:P17 ?c }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . ?p rdfs:label ?place . ?c rdfs:label ?country . }
} ORDER BY ?year ?film'> data/best_film_locations.csv

# 3. Directors with birthplace coordinates.
Q 'SELECT DISTINCT ?director ?film ?year ?birthplace ?birth_country ?lon ?lat WHERE {
  ?f p:P166 ?st . ?st ps:P166 wd:Q3600406 . ?f wdt:P31/wdt:P279* wd:Q11424 .
  OPTIONAL { ?st pq:P585 ?t } OPTIONAL { ?f wdt:P577 ?pub } BIND(YEAR(COALESCE(?t,?pub)) AS ?year)
  ?f rdfs:label ?film FILTER(LANG(?film)="en")
  ?f wdt:P57 ?d . ?d rdfs:label ?director FILTER(LANG(?director)="en")
  OPTIONAL { ?d wdt:P19 ?b . ?b wdt:P625 ?coord . ?b rdfs:label ?birthplace FILTER(LANG(?birthplace)="en")
    OPTIONAL { ?b wdt:P17 ?c . ?c rdfs:label ?birth_country FILTER(LANG(?birth_country)="en") }
    BIND(geof:longitude(?coord) AS ?lon) BIND(geof:latitude(?coord) AS ?lat) }
} ORDER BY ?year' > data/best_film_directors.csv

wc -l data/best_film_*.csv
