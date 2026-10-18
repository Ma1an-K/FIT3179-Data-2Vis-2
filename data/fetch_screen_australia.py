#!/usr/bin/env python3
"""Transcribes three Screen Australia Infogram tables into CSV. Run from the repo root: python3 data/fetch_screen_australia.py
Sources (accessed 2026-10-12):
  spend   https://www.screenaustralia.gov.au/insights-and-trends/drama-production/spend-by-location/
  top100  https://www.screenaustralia.gov.au/insights-and-trends/australian-films/top-australian-films/
  top5    https://www.screenaustralia.gov.au/insights-and-trends/australian-films/top-5-each-year/
Each page embeds an Infogram chart; the numbers are copied verbatim from the embed's window.infographicData JSON."""
import csv, json, re, sys, urllib.request
from pathlib import Path

D = Path(__file__).parent
EMBEDS = {
    "spend": "df11c829-3984-48b5-b50c-5ae2358ce92e",
    "top100": "5d694169-0897-48b5-8046-2121b2569dba",
    "top5": "95e85f20-c7b4-4f2a-b194-3cfb952a5cff",
}
UA = "FIT3179-student-project/0.1 (contact: info@ormada.com.au)"

def infogram(eid):
    req = urllib.request.Request(f"https://e.infogram.com/{eid}?src=embed", headers={"User-Agent": UA})
    html = urllib.request.urlopen(req, timeout=60).read().decode("utf-8")
    m = re.search(r"window\.infographicData\s*=\s*(\{.*?\});\s*</script>", html, re.S)
    if not m: sys.exit(f"no infographicData in embed {eid}")
    return json.loads(m.group(1))

def tables(d):
    """Every list-of-lists table (cells are {'value': …} dicts) anywhere in the JSON, in document order."""
    out = []
    def walk(x):
        if isinstance(x, dict):
            for v in x.values(): walk(v)
        elif isinstance(x, list):
            if len(x) > 1 and all(isinstance(r, list) for r in x) and x[0] and isinstance(x[0][0], (dict, type(None))):
                out.append([[cell(c) for c in r] for r in x]); return
            for v in x: walk(v)
    walk(d); return out

def cell(c):
    if c is None: return ""
    if "value" in c and c["value"] not in (None, ""): return str(c["value"]).strip()
    s = c.get("ct", {}).get("s")
    return "".join(p.get("v", "") for p in s).strip() if s else ""

def num(s):
    """'1,105' -> 1105.0; ' 832 ' -> 832.0; '<0.1' -> (0.05, approx); '<1%' -> (0.5, approx); '32%' -> 32.0"""
    s = s.strip().rstrip("%").strip()
    if s.startswith("<"): return float(s[1:]) / 2, 1
    return float(s.replace(",", "")), 0

def is_win(title, release_year):
    """Winner record for a title, only if the release year is the award year or the year before (rejects remakes such as Storm Boy 2019 vs the 1977 winner)."""
    win = wkey.get(norm(title))
    return win if win and 0 <= int(win["year"]) - int(release_year) <= 1 else None

def norm(t):
    t = t.lower().replace("*", "")
    t = re.sub(r"\(.*?\)", "", t).strip()
    if t.endswith(", the"): t = "the " + t[:-5]
    return re.sub(r"[^a-z0-9]+", " ", t).strip()

winners = list(csv.DictReader((D / "best_film_winners.csv").open(newline="")))
wkey = {norm(r["film"]): r for r in winners}

# --- spend by location -------------------------------------------------------------------------
spend_tables = [t for t in tables(infogram(EMBEDS["spend"])) if len(t) == 31]
assert len(spend_tables) == 2, f"expected the two 30-year tables, got {len(spend_tables)}"
dollars, shares = spend_tables
STATES = ["NSW", "Qld", "Vic", "SA", "WA", "ACT/Tas/NT"]
assert [h.strip().rstrip("*").replace(", ", "/").replace("Tas/NT", "Tas/NT") for h in dollars[0][1:]] == ["NSW", "Qld", "Vic", "SA", "WA", "ACT/Tas/NT"], dollars[0]
COMBINED = {}
rows = []
for dr, sr in zip(dollars[1:], shares[1:]):
    label = dr[0].rstrip("^"); assert label == sr[0].rstrip("^"), (label, sr[0])
    y0 = int(label.split("/")[0])
    merged = dr[6] == "" and dr[5].endswith("^")   # 2010/11: WA and ACT/Tas/NT published as one combined figure (footnote ^)
    for i, st in enumerate(STATES):
        if merged and st in ("WA", "ACT/Tas/NT"):
            rows.append([label, y0, st, "", "", 2]); continue   # approx=2: published only as a WA+ACT+Tas+NT total, so left blank
        m, a1 = num(dr[i + 1]); p, a2 = num(sr[i + 1])
        rows.append([label, y0, st, int(m) if m == int(m) else m, int(p) if p == int(p) else p, int(a1 or a2)])
    if merged: COMBINED[label] = (num(dr[5].rstrip("^"))[0], num(sr[5].rstrip("^"))[0])
assert rows[0][:2] == ["1995/96", 1995] and rows[-1][0] == "2024/25" and len(rows) == 180, (rows[0], rows[-1], len(rows))
for y in {r[0] for r in rows}:
    s = sum(r[4] for r in rows if r[0] == y and r[4] != "") + COMBINED.get(y, (0, 0))[1]; assert 97 <= s <= 103, f"{y} shares sum to {s}"
with open(D / "spend_by_state_series.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["year_label", "year_start", "state", "spend_m", "share_pct", "approx"]); w.writerows(rows)

last = {r[2]: r[3] for r in rows if r[0] == "2024/25"}
total = sum(last.values())
assert abs(total - 2690) < 1, total
FULL = {"NSW": "New South Wales", "Qld": "Queensland", "Vic": "Victoria", "SA": "South Australia", "WA": "Western Australia"}
with open(D / "spend_by_state_2024_25.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["state", "share_pct", "note"])
    for st, full in FULL.items(): w.writerow([full, round(last[st] / total * 100, 1), ""])
    for full in ["Australian Capital Territory", "Northern Territory", "Tasmania"]:
        w.writerow([full, round(last["ACT/Tas/NT"] / total * 100, 1), "combined with ACT, NT and Tasmania"])

# --- top 100 of all time -----------------------------------------------------------------------
t100 = [t for t in tables(infogram(EMBEDS["top100"])) if len(t) == 101][0]
assert [c.lower() for c in t100[0][:2]] == ["rank", "title"], t100[0]
with open(D / "top100_box_office.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["rank", "title", "distributor", "release_year", "box_office_aud", "is_winner", "winner_title"])
    hits = 0
    for r in t100[1:]:
        win = is_win(r[1], int(num(r[3])[0]))
        hits += bool(win)
        w.writerow([int(num(r[0])[0]), r[1], r[2], int(num(r[3])[0]), int(num(r[4])[0]), int(bool(win)), win["film"] if win else ""])
assert hits == 22, f"expected 22 winners in the top 100, matched {hits}"

# --- top 5 each year ---------------------------------------------------------------------------
t5 = tables(infogram(EMBEDS["top5"]))
blocks = [t for t in t5 if len(t) == 6 and t[0][0].lower() == "rank"]
assert len(blocks) == 38, f"expected 38 yearly blocks 1988–2025, got {len(blocks)}"
t5rows = []
for i, b in enumerate(blocks):
    year = 1988 + i  # blocks run 1988-2025: block 0 is Crocodile Dundee II, the last is Bring Her Back
    for r in b[1:]:
        t5rows.append([year, int(num(r[0])[0]), r[1], r[2], int(num(r[3])[0])])
def year_of(title):
    return [r[0] for r in t5rows if norm(r[2]) == norm(title)]
for title, y in [("Proof", 1991), ("Strictly Ballroom", 1992), ("The Piano", 1993), ("Two Hands", 1999), ("Elvis", 2022)]:
    assert y in year_of(title), f"{title}: expected {y} in {year_of(title)} — block order assumption broken"
with open(D / "top5_each_year.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["year", "rank", "title", "distributor", "box_office_aud"]); w.writerows(t5rows)

# --- winners vs the year's top Australian film -------------------------------------------------
with open(D / "winner_vs_top.csv", "w", newline="") as f:
    w = csv.writer(f, lineterminator="\n"); w.writerow(["film", "year", "winner_gross", "winner_rank", "top_title", "top_gross", "winner_is_top"])
    n = 0; seen = {}   # film -> (row, gross); a film in two yearly blocks (Evil Angels 1988 and 1989) keeps the block with the larger gross
    for r in t5rows:
        win = is_win(r[2], r[0])
        if not win or int(win["year"]) < 1988: continue
        # a winner's release year can differ from its award year by one; prefer the block whose year matches, else award year - 1
        top = [t for t in t5rows if t[0] == r[0] and t[1] == 1][0]
        row = [win["film"], r[0], r[4], r[1], top[2].replace("*", ""), top[4], int(r[1] == 1)]
        if win["film"] not in seen or r[4] > seen[win["film"]][2]: seen[win["film"]] = row
    w.writerows(sorted(seen.values(), key=lambda x: x[1])); n = len(seen)
    assert n >= 15, f"only {n} winners found in the top-5 tables"
print("OK: spend 180 rows | top100 winners", hits, "| top5", len(t5rows), "| winner_vs_top", n)
