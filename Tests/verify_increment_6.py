from pathlib import Path
s = Path('Sources/InventoryIntelligenceApp.swift').read_text()
for expected in ['struct HardwareAttributes: Codable','managementPlatform','enrollmentStatus','lastInventoryUpdate','assetTag','struct PlanningPolicy: Codable','overrides: [String: Int]','modelCosts: [String: Double]','case .intelligence:', 'Export Budget CSV','policy.target(for: device)','policy.save()']:
    assert expected in s, f'Missing {expected}'
assert 'value: 4, to:' in s, 'Previously validated four-year classification must remain'
print('PASS: Increment 6 additive source contract checks (not a native macOS test)')
