"""Sanity checks on the exported CSVs. Run: python3 data/check_data.py"""
import csv, sys
from pathlib import Path

D = Path(__file__).parent
HEADERS = {
    "best_film_winners.csv": "film_qid,film,year,director",
    "best_film_locations.csv": "film,year,kind,place,country,lon,lat,level",
    "best_film_settings.csv": "film,year,setting",
    "best_film_directors.csv": "director,film,year,birthplace,birth_country,lon,lat",
    "best_film_genres.csv": "film,year,genre,genre_group",
    "best_film_facts.csv": "film,year,cast_size,runtime_min",
    "director_careers.csv": "director,films_directed,best_film_wins,first_win,last_win",
    "spend_by_state_series.csv": "year_label,year_start,state,spend_m,share_pct,approx",
    "spend_by_state_2024_25.csv": "state,share_pct,note",
    "top100_box_office.csv": "rank,title,distributor,release_year,box_office_aud,is_winner,winner_title",
    "top5_each_year.csv": "year,rank,title,distributor,box_office_aud",
    "winner_vs_top.csv": "film,year,winner_gross,winner_rank,top_title,top_gross,winner_is_top",
    "oscar_best_picture.csv": "film,year,runtime_min",
}
for name, hdr in HEADERS.items():
    first = (D / name).open().readline().strip()
    assert first == hdr, f"{name}: bad header line {first[:60]!r}"
errors = []

winners = list(csv.DictReader((D / "best_film_winners.csv").open()))
assert winners[0].keys() >= {"film_qid", "film", "year", "director"}, "winners columns"
if not 56 <= len(winners) <= 60: errors.append(f"winners count {len(winners)}")
if any(not r["year"] for r in winners): errors.append("winner with empty year")
years = [r["year"] for r in winners]
if years.count("2014") != 2: errors.append("2014 tie not present twice")
if years.count("1973") != 2: errors.append("1973 joint winners not present twice")

locs = list(csv.DictReader((D / "best_film_locations.csv").open()))
if any(not r["lon"] or not r["lat"] for r in locs): errors.append("location without coords")
if any(r["kind"] not in ("setting", "filming") for r in locs): errors.append("bad kind")
if any(r["level"] not in ("country", "place") for r in locs): errors.append("bad level")
if any(r["level"] == "place" and abs(float(r["lon"]) - 133.0) < 0.01 and abs(float(r["lat"]) + 25.0) < 0.01 for r in locs):
    errors.append("country-centroid 'Australia' row still present")
if len(locs) < 40: errors.append(f"too few location rows {len(locs)}")

settings = list(csv.DictReader((D / "best_film_settings.csv").open()))
if len(settings) != len(winners): errors.append(f"settings rows {len(settings)} != winners {len(winners)}")
ALLOWED = ("Set in Australia", "Set overseas", "No setting data")
if any(r["setting"] not in ALLOWED for r in settings): errors.append("bad setting value")
counts = {k: sum(r["setting"] == k for r in settings) for k in ALLOWED}
if counts != {"Set in Australia": 37, "Set overseas": 7, "No setting data": 14}:
    errors.append(f"settings counts changed; update the legend domain in js/2_2_waffle.json: {counts}")
if counts["Set in Australia"] < 25: errors.append(f"too few Set in Australia: {counts}")
if counts["No setting data"] > 16: errors.append(f"too many films without setting data (manual films not queried?): {counts}")

dirs = list(csv.DictReader((D / "best_film_directors.csv").open()))
with_coords = [r for r in dirs if r["lon"]]
if len(with_coords) < 50: errors.append(f"too few directors with coords {len(with_coords)}")

pairs = [(r["director"], r["film"]) for r in dirs]
if len(pairs) != len(set(pairs)): errors.append("duplicate (director, film) rows")
if any(r["birthplace"] and r["birthplace"] == r["birth_country"] for r in dirs): errors.append("country-level birthplace row")
if any(r["lon"] and abs(float(r["lon"]) - 133.0) < 0.01 and abs(float(r["lat"]) + 25.0) < 0.01 for r in dirs):
    errors.append("Australia centroid in directors")

flows = list(csv.DictReader((D / "flows.csv").open()))
if len(flows) < 24: errors.append(f"too few flow rows {len(flows)}")
if any(abs(float(r["lon2"]) - 133.0) < 0.01 and abs(float(r["lat2"]) + 25.0) < 0.01 for r in flows if r["lon2"] and r["lat2"]):
    errors.append("flow ending at the Australia country centroid")
if any(not r[k] for r in flows for k in ("lon1", "lat1", "lon2", "lat2")): errors.append("flow with missing endpoint")
fp = [(r["director"], r["film"]) for r in flows]
if len(fp) != len(set(fp)): errors.append("duplicate (director, film) flow rows")
genres = list(csv.DictReader((D / "best_film_genres.csv").open()))
if len({r["film"] for r in genres}) < 54: errors.append("fewer than 54 films with a genre")
groups = {r["genre_group"] for r in genres}
if len(groups) != 9 or "Other" not in groups: errors.append(f"genre_group should be 8 genres + Other, got {sorted(groups)}")
facts = list(csv.DictReader((D / "best_film_facts.csv").open()))
if len(facts) != len(winners): errors.append(f"facts rows {len(facts)} != winners")
if sum(int(r["cast_size"]) > 0 for r in facts) < 50: errors.append("fewer than 50 films with a cast list")
if sum(bool(r["runtime_min"]) for r in facts) < 50: errors.append("fewer than 50 films with a runtime")
if any(r["runtime_min"] and not 40 <= int(r["runtime_min"]) <= 240 for r in facts): errors.append("implausible runtime")
careers = list(csv.DictReader((D / "director_careers.csv").open()))
if len(careers) != len({r["director"] for r in careers}): errors.append("duplicate director in careers")
if any(int(r["best_film_wins"]) > int(r["films_directed"]) for r in careers): errors.append("wins exceed films directed")
if sum(int(r["best_film_wins"]) for r in careers) < 58: errors.append("career wins do not cover the winners")
series = list(csv.DictReader((D / "spend_by_state_series.csv").open()))
if len(series) != 180: errors.append(f"spend series rows {len(series)}")
if {r["state"] for r in series} != {"NSW", "Qld", "Vic", "SA", "WA", "ACT/Tas/NT"}: errors.append("spend series states")
spend24 = list(csv.DictReader((D / "spend_by_state_2024_25.csv").open()))
if len(spend24) != 8 or any("." not in r["share_pct"] for r in spend24): errors.append("2024/25 shares must be 8 rows with one decimal")
if abs(sum(float(r["share_pct"]) for r in spend24[:5]) + float(spend24[5]["share_pct"]) - 100) > 0.5: errors.append("2024/25 shares do not sum to 100")
top100 = list(csv.DictReader((D / "top100_box_office.csv").open()))
# 22 not 19: the year-aware match finds 22 winners in the top 100 (incl. Elvis, Talk to Me, Better Man); Storm Boy (2019 remake) is rejected
if len(top100) != 100 or sum(r["is_winner"] == "1" for r in top100) != 22: errors.append("top100 rows / winner matches")
t5 = list(csv.DictReader((D / "top5_each_year.csv").open()))
# the Infogram blocks cover 1988-2025 (not 1987-2024): block 0 is Crocodile Dundee II, the last block is Bring Her Back
if len(t5) != 190 or {r["year"] for r in t5} != {str(y) for y in range(1988, 2026)}: errors.append("top5 rows or years")
wvt = list(csv.DictReader((D / "winner_vs_top.csv").open()))
if len(wvt) < 15 or len({r["film"] for r in wvt}) != len(wvt): errors.append("winner_vs_top rows or duplicates")
if any(int(r["winner_gross"]) > int(r["top_gross"]) for r in wvt): errors.append("winner gross above the year's top gross")
oscar = list(csv.DictReader((D / "oscar_best_picture.csv").open()))
if not 55 <= len(oscar) <= 60: errors.append(f"oscar rows {len(oscar)}")
if {int(r["year"]) for r in oscar} != set(range(1969, 2026)): errors.append("oscar years must cover 1969-2025")
if any(not r["runtime_min"] for r in oscar): errors.append("oscar winner without runtime")
if any(r["runtime_min"] and not 80 <= int(r["runtime_min"]) <= 240 for r in oscar): errors.append("implausible oscar runtime")
import json
for jf in sorted((D.parent / "js").glob("*.json")):
    txt = json.dumps(json.loads(jf.read_text()))
    if "data/best_film_directors.csv" in txt and '"parse"' not in txt: errors.append(f"{jf.name} reads the directors CSV without a numeric parse")
print("flows", len(flows))
print("settings", counts)
print("winners", len(winners), "| locations", len(locs), "| directors w/ coords", len(with_coords))
if errors:
    print("FAIL:", *errors, sep="\n  "); sys.exit(1)
print("OK")
