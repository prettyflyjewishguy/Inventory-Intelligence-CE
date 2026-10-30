from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'Sources/InventoryIntelligenceApp.swift').read_text()
assert 'func label(for device: DeviceRecord' in s
assert 'Lifecycle.label(device.dateAdded)' not in s
assert 'value: 4, to:' not in s
assert 'policy.target(for: record)' in s
assert 'policy.target(for: device)' in s
assert 'DeviceDetailsSheet(device: device, sourceName: store.sourceName, policy: policy)' in s
assert '"Lifecycle Policy"' in s
assert 'policy.label(for: $0)' in s
assert 'policy.label(for: device)' in s
print('Increment 7 shared policy source checks passed')
