# Data sources

## 1. Wikidata — AFI/AACTA Award for Best Film (Q3600406)
Licence CC0. Retrieved 2026-10-10 with `fetch_wikidata.sh` (queries inside).
- `best_film_winners.csv` — one row per winning film: `film_qid, film, year, director`
- `best_film_locations.csv` — story settings (P840) and filming locations (P915) with coordinates; country-level places excluded
- `best_film_directors.csv` — directors with birthplace (P19) coordinates

Known gaps (winners on Wikipedia's list not linked to the award on Wikidata, as of 2026-10-10; bold rows on https://en.wikipedia.org/wiki/AACTA_Award_for_Best_Film, year as listed there):
- 1969 — Jack and Jill: A Postscript
- 1970 — Three to Go: Michael
- 1971 — Homesdale
- 1972 — Stork
- 1973 — 27A
- 1973 — Libido: The Child
- 1974 — Sunday Too Far Away
- 1991 — Proof
- 2022 — Elvis
- 2023 — Talk to Me
- 2024 — Better Man
- 2025 — Bring Her Back

## 2. Screen Australia — Drama Report 2024/25
Published 4 December 2025. https://www.screenaustralia.gov.au/drama-report-2024-25-2-7-billion-spent-on-drama-production-in-australia-points-to-holistic-industry-growth/
- `spend_by_state_2024_25.csv` — transcribed verbatim from the release (Task 3). ACT, NT and Tasmania are published only as a combined 1%.

## Boundaries
- `js/au_states.geojson` — Australian states, simplified, from https://github.com/tonywr71/GeoJson-Data (derived from ABS boundaries)
- `js/ne_110m_admin_0_countries.topojson` — Natural Earth 1:110m countries via the FIT3179 Week 8 studio repository
