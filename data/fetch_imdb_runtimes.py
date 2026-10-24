#!/usr/bin/env python3
"""World median feature-film runtime per release year, from IMDb's title.basics file.
Run from the repo root: python3 data/fetch_imdb_runtimes.py path/to/title.basics.tsv.gz

Source: https://datasets.imdbws.com/title.basics.tsv.gz (downloaded 2026-10-24; not kept in the repo, ~229 MB)
Licence: IMDb non-commercial datasets, personal and non-commercial use, https://developer.imdb.com/non-commercial-datasets/
Only the derived yearly medians and counts are published here.

Filter rules (a title is kept only if all hold):
  titleType == "movie"           feature films only (no TV movies, shorts, episodes or videos)
  isAdult == "0"                 excludes adult titles
  40 <= runtimeMinutes <= 300    40-minute floor excludes shorts mislabelled as features;
                                 300-minute cap excludes art installations and endurance films
  1969 <= startYear <= 2025      the span of the AACTA/AFI Best Film award
`\\N` is IMDb's null marker; titles with a null or non-numeric runtime or year are dropped.

Output: data/world_runtime_by_year.csv with columns year,median_runtime,films (median to one decimal)."""
import csv, gzip, statistics, sys
from collections import defaultdict
from pathlib import Path

OUT = Path(__file__).parent / "world_runtime_by_year.csv"
Y0, Y1 = 1969, 2025

def main(src):
    csv.field_size_limit(sys.maxsize)
    by_year = defaultdict(list)
    with gzip.open(src, "rt", encoding="utf-8", newline="") as f:
        rows = csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
        header = next(rows)
        i = {k: header.index(k) for k in ("titleType", "isAdult", "startYear", "runtimeMinutes")}
        for r in rows:
            if len(r) != len(header) or r[i["titleType"]] != "movie" or r[i["isAdult"]] != "0":
                continue
            y, m = r[i["startYear"]], r[i["runtimeMinutes"]]
            if not (y.isdigit() and m.isdigit()):  # also rejects \N
                continue
            y, m = int(y), int(m)
            if Y0 <= y <= Y1 and 40 <= m <= 300:
                by_year[y].append(m)
    with OUT.open("w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["year", "median_runtime", "films"])
        for y in range(Y0, Y1 + 1):
            v = by_year[y]
            w.writerow([y, f"{statistics.median(v):.1f}", len(v)])
    print(f"wrote {OUT} ({Y1 - Y0 + 1} years)")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python3 data/fetch_imdb_runtimes.py path/to/title.basics.tsv.gz")
    main(sys.argv[1])
