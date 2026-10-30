from pathlib import Path
import csv
root = Path(__file__).resolve().parents[1]
s = (root/'Sources/InventoryIntelligenceApp.swift').read_text()
assert 'LazyVStack(alignment: .leading, spacing: 0)' in s
assert 'pagedDeviceRows(store.devices.sorted' in s
assert 'page: $analyticsPage' in s
assert 'debouncedReportSearch' in s and '.task(id: reportSearch)' in s
assert 'optionalIndices = optionalFields.map { index($0) }' in s
assert 'dashboardMetric("Replacement review", "\(analyticsCount(.review))"' in s
assert 'policy.label(for: device)' in s
assert 'policy.target(for: record)' in s
for n in (5000,10000):
    with (root/f'sample_inventory_{n}.csv').open(newline='') as f:
        rows=list(csv.DictReader(f))
    assert len(rows)==n,(n,len(rows))
    assert len({r['Serial'] for r in rows})==n
print('PASS: Increment 8 source checks and 5k/10k datasets')
