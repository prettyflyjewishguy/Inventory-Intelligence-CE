import csv
from pathlib import Path
p = Path(__file__).resolve().parents[1] / "sample_inventory_1000.csv"
with p.open(newline="", encoding="utf-8") as f:
    rows=list(csv.DictReader(f))
assert len(rows)==1000
assert len({r["Serial"] for r in rows})==1000
assert all(r["Serial"] and r["Model"] for r in rows)
assert sum(not r["Date Added"] for r in rows)==200
assert sum(not r["Assigned User"] for r in rows)==76
print("Increment 3.1 synthetic dataset: PASS (1000 unique devices)")
