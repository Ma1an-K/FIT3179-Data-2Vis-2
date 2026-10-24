# Data sources

## 1. Wikidata — AFI/AACTA Award for Best Film (Q3600406)
Licence CC0. Retrieved 2026-10-11 with `fetch_wikidata.sh` (queries inside).
- `best_film_winners.csv` — one row per winning film: `film_qid, film, year, director`
- `best_film_locations.csv` — story settings (P840) and filming locations (P915) with coordinates; a `level` column marks country-level places (`country`, centroid only, ignored by the map) versus real places (`place`)
- `best_film_settings.csv` — derived by `fetch_wikidata.sh`: one row per winner (`film, year, setting`), `Set in Australia` if any recorded setting is in Australia (including country-level), else `Set overseas` if any setting is recorded, else `No setting data`
- `best_film_directors.csv` — directors with birthplace (P19) coordinates
- `best_film_genres.csv` — `film, year, genre, genre_group`: one row per film x genre (Wikidata P136, English labels). `genre_group` keeps the 8 most common genres across the 58 winners and folds the rest into `Other`. Retrieved 2026-10-12.
- `best_film_facts.csv` — `film, year, cast_size, runtime_min`: distinct cast members (P161) and runtime in minutes (P2047, minimum if several; empty if unrecorded). Retrieved 2026-10-12.
- `director_careers.csv` — `director, films_directed, best_film_wins, first_win, last_win`: `films_directed` counts Wikidata film items with this director (P57), so it undercounts directors with thin Wikidata coverage; `best_film_wins` counts the winners among the 58. Libido counts its three omnibus directors. Retrieved 2026-10-12.

Some recorded settings are region-level (e.g. a whole state); their centroid is used.
Country-level settings still count in `best_film_settings.csv`, so films such as Mad Max: Fury Road and Gallipoli, whose only recorded setting is "Australia", count as `Set in Australia`.
`flows.csv` excludes country-level settings (centroid only), so a film set only in a whole country has no flow row.

### Wikipedia-sourced winners
Twelve winning films are not linked to the award on Wikidata. They are listed in `manual_winners.csv` (with a `source_url` column) and appended to `best_film_winners.csv` by `fetch_wikidata.sh`. Source: https://en.wikipedia.org/wiki/AACTA_Award_for_Best_Film (bold rows), checked 2026-10-11. These 12 films are identified by their Wikidata items and queried for settings, directors and birthplaces like the others; only the award link itself is missing on Wikidata. `film_qid` is the item from `source_url`; `fetch_wikidata.sh` queries them by QID in steps 2c, 3c and 4c (separate queries, because a UNION with the award-linked films timed out) and takes their year from `manual_winners.csv`. Directors were read from each film's Wikidata P57; `source_url` is that film's Wikidata page.
- 1969 Jack and Jill: A Postscript; 1970 Three to Go: Michael; 1971 Homesdale; 1972 Stork; 1973 27A; 1973 Libido: The Child (joint winners, two rows for 1973); 1975 Sunday Too Far Away (Wikipedia lists 1974-75; 1975 used); 1991 Proof; 2022 Elvis; 2023 Talk to Me; 2024 Better Man; 2025 Bring Her Back.
- Libido: the Wikidata item is the whole 1973 omnibus film "Libido", so its three listed directors (John B. Murray; Tim Burstall; Fred Schepisi) are recorded, not just the director of "The Child" segment.

## 2. Screen Australia — Infogram tables
Accessed 2026-10-12 by `fetch_screen_australia.py` (run from the repo root; it downloads each embed and parses `window.infographicData`, copying the numbers verbatim). Screen Australia publishes these tables only as Infogram charts.
- Spend by location (drama production, $M and % by state, 1995/96-2024/25): https://www.screenaustralia.gov.au/insights-and-trends/drama-production/spend-by-location/ , Infogram embed `df11c829-3984-48b5-b50c-5ae2358ce92e`
- Top Australian films of all time (top 100): https://www.screenaustralia.gov.au/insights-and-trends/australian-films/top-australian-films/ , embed `5d694169-0897-48b5-8046-2121b2569dba`
- Top 5 Australian films each year (1988-2025): https://www.screenaustralia.gov.au/insights-and-trends/australian-films/top-5-each-year/ , embed `95e85f20-c7b4-4f2a-b194-3cfb952a5cff`

Files:
- `spend_by_state_series.csv` — `year_label, year_start, state, spend_m, share_pct, approx`; 30 years x 6 groups (NSW, Qld, Vic, SA, WA, ACT/Tas/NT) = 180 rows. `approx` = 1 where the source says `<1%` or `<0.1` (stored as half the bound: 0.5 and 0.05); `approx` = 2 for 2010/11, where Screen Australia published WA, ACT, Tasmania and NT as one combined figure ($8M, 1%) for confidentiality, so the WA and ACT/Tas/NT cells are left blank rather than split.
- `spend_by_state_2024_25.csv` — `state, share_pct, note`; the 2024/25 shares computed from the $M row (total $2,690M), one decimal. ACT, NT and Tasmania are published only as a combined figure, so each carries the combined value and the note.
- `top100_box_office.csv` — `rank, title, distributor, release_year, box_office_aud, is_winner, winner_title`; `is_winner` = 1 when the title matches an AACTA Best Film winner (case, `The`/`, The`, asterisks and parentheticals ignored) and the release year is the award year or the one before (this rejects the 2019 Storm Boy remake). 22 of the 100 are winners.
- `top5_each_year.csv` — `year, rank, title, distributor, box_office_aud`; 38 yearly blocks, 1988-2025, 5 films each.
- `winner_vs_top.csv` — `film, year, winner_gross, winner_rank, top_title, top_gross, winner_is_top`; winners that appear in a yearly top 5, with that year's number-one film. A film appearing in two yearly blocks (Evil Angels, 1988 and 1989) keeps the row with the larger gross.

Cleaning rules: thousands separators, padding spaces, trailing `%`, footnote carets (`^`) and title asterisks are stripped; `*` on a state header and on a title is Screen Australia's footnote marker.

Box office is cumulative Australian gross in current dollars as reported April 2025; the top-5 table gives year-of-release gross and can differ slightly from the all-time list.

Screen Australia states no open licence; used under its site terms with attribution.

Winners not in the top 100 (36): The Devil's Playground; Storm Boy; Newsfront; My Brilliant Career; Lonely Hearts; Careful, He Might Hear You; Annie's Coming Out; Bliss; Malcolm; The Year My Voice Broke; The Navigator: A Medieval Odyssey; Evil Angels; Flirting; Angel Baby; Kiss or Kill; The Interview; Somersault; Look Both Ways; Ten Canoes; Romulus, My Father; The Black Balloon; Samson and Delilah; The Babadook; Sweet Country; The Nightingale; Babyteeth; Nitram; Jack and Jill: A Postscript; Three to Go: Michael; Homesdale; Stork; 27A; Libido: The Child; Sunday Too Far Away; Proof; Bring Her Back.

## 3. Wikidata — Academy Award for Best Picture (Q102427)
Licence CC0. Retrieved 2026-10-24 with query 8 in `fetch_wikidata.sh`. Used as the comparison series in chart 4.2.
- `oscar_best_picture.csv` — `film, year, runtime_min`: one row per Best Picture winner, 57 rows, honoured years 1969-2025 (one winner each, no ties). The award statement's point in time (P585) is the ceremony date, so `year` = ceremony year - 1 (e.g. Everything Everywhere All at Once, ceremony 2023, `year` 2022). Runtime is P2047 (best rank), converted to minutes where Wikidata stores it in seconds (Oppenheimer, One Battle After Another), rounded; every winner has one. Runtime rule for this series only: when several runtimes are recorded, a value qualified "applies to part" (P518) = theatrical version (Q26225765) is used, otherwise the LONGEST value is kept, because the shorter unqualified values are usually TV or alternate cuts (The Godfather Part II has 165 and 202 recorded; 202 is used). The theatrical qualifier keeps director's and extended cuts out (Dances with Wolves 181, not 236; The Lord of the Rings: The Return of the King 200, not 263; Crash 112, not 115). `best_film_facts.csv` keeps its own minimum rule. Values are otherwise Wikidata's as recorded: Midnight Cowboy is 108 (often quoted as 113).

## Boundaries
- `js/au_states.geojson` — Australian states, simplified, from https://github.com/tonywr71/GeoJson-Data (derived from ABS boundaries)
Retrieved 2026-10-11
- `js/ne_110m_admin_0_countries.topojson` — Natural Earth 1:110m countries via the FIT3179 Week 8 studio repository
Retrieved 2026-10-11
