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
print("flows", len(flows))
print("settings", counts)
print("winners", len(winners), "| locations", len(locs), "| directors w/ coords", len(with_coords))
if errors:
    print("FAIL:", *errors, sep="\n  "); sys.exit(1)
print("OK")
