"""Sanity checks on the exported CSVs. Run: python3 data/check_data.py"""
import csv, sys
from pathlib import Path

D = Path(__file__).parent
HEADERS = {
    "best_film_winners.csv": "film_qid,film,year,director",
    "best_film_locations.csv": "film,year,kind,place,country,lon,lat",
    "best_film_directors.csv": "director,film,year,birthplace,birth_country,lon,lat",
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
if any(abs(float(r["lon"]) - 133.0) < 0.01 and abs(float(r["lat"]) + 25.0) < 0.01 for r in locs):
    errors.append("country-centroid 'Australia' row still present")
if len(locs) < 40: errors.append(f"too few location rows {len(locs)}")

dirs = list(csv.DictReader((D / "best_film_directors.csv").open()))
with_coords = [r for r in dirs if r["lon"]]
if len(with_coords) < 35: errors.append(f"too few directors with coords {len(with_coords)}")

pairs = [(r["director"], r["film"]) for r in dirs]
if len(pairs) != len(set(pairs)): errors.append("duplicate (director, film) rows")
if any(r["birthplace"] and r["birthplace"] == r["birth_country"] for r in dirs): errors.append("country-level birthplace row")
if any(r["lon"] and abs(float(r["lon"]) - 133.0) < 0.01 and abs(float(r["lat"]) + 25.0) < 0.01 for r in dirs):
    errors.append("Australia centroid in directors")

print("winners", len(winners), "| locations", len(locs), "| directors w/ coords", len(with_coords))
if errors:
    print("FAIL:", *errors, sep="\n  "); sys.exit(1)
print("OK")
