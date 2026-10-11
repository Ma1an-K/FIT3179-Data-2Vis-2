# Data sources

## 1. Wikidata — AFI/AACTA Award for Best Film (Q3600406)
Licence CC0. Retrieved 2026-10-11 with `fetch_wikidata.sh` (queries inside).
- `best_film_winners.csv` — one row per winning film: `film_qid, film, year, director`
- `best_film_locations.csv` — story settings (P840) and filming locations (P915) with coordinates; a `level` column marks country-level places (`country`, centroid only, ignored by the map) versus real places (`place`)
- `best_film_settings.csv` — derived by `fetch_wikidata.sh`: one row per winner (`film, year, setting`), `Set in Australia` if any recorded setting is in Australia (including country-level), else `Set overseas` if any setting is recorded, else `No setting data`
- `best_film_directors.csv` — directors with birthplace (P19) coordinates

Some recorded settings are region-level (e.g. a whole state); their centroid is used.
Country-level settings still count in `best_film_settings.csv`, so films such as Mad Max: Fury Road and Gallipoli, whose only recorded setting is "Australia", count as `Set in Australia`.
`flows.csv` excludes country-level settings (centroid only), so a film set only in a whole country has no flow row.

### Wikipedia-sourced winners
Twelve winning films are not linked to the award on Wikidata. They are listed in `manual_winners.csv` (with a `source_url` column) and appended to `best_film_winners.csv` by `fetch_wikidata.sh`. Source: https://en.wikipedia.org/wiki/AACTA_Award_for_Best_Film (bold rows), checked 2026-10-11. These 12 films are identified by their Wikidata items and queried for settings, directors and birthplaces like the others; only the award link itself is missing on Wikidata. `film_qid` is the item from `source_url`; `fetch_wikidata.sh` queries them by QID in steps 2c, 3c and 4c (separate queries, because a UNION with the award-linked films timed out) and takes their year from `manual_winners.csv`. Directors were read from each film's Wikidata P57; `source_url` is that film's Wikidata page.
- 1969 Jack and Jill: A Postscript; 1970 Three to Go: Michael; 1971 Homesdale; 1972 Stork; 1973 27A; 1973 Libido: The Child (joint winners, two rows for 1973); 1975 Sunday Too Far Away (Wikipedia lists 1974-75; 1975 used); 1991 Proof; 2022 Elvis; 2023 Talk to Me; 2024 Better Man; 2025 Bring Her Back.
- Libido: the Wikidata item is the whole 1973 omnibus film "Libido", so its three listed directors (John B. Murray; Tim Burstall; Fred Schepisi) are recorded, not just the director of "The Child" segment.

## 2. Screen Australia — Drama Report 2024/25
Published 4 December 2025. https://www.screenaustralia.gov.au/drama-report-2024-25-2-7-billion-spent-on-drama-production-in-australia-points-to-holistic-industry-growth/
Retrieved 2026-10-11
- `spend_by_state_2024_25.csv` — transcribed verbatim from the release (Task 3). ACT, NT and Tasmania are published only as a combined 1%.

## Boundaries
- `js/au_states.geojson` — Australian states, simplified, from https://github.com/tonywr71/GeoJson-Data (derived from ABS boundaries)
Retrieved 2026-10-11
- `js/ne_110m_admin_0_countries.topojson` — Natural Earth 1:110m countries via the FIT3179 Week 8 studio repository
Retrieved 2026-10-11
