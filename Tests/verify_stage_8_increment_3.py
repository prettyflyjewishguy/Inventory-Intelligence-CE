from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'Sources/InventoryIntelligenceApp.swift').read_text()
checks = {
 'exact missing assignment drilldown': 'qualityScope = .missingUser' in s,
 'exact missing date drilldown': 'qualityScope = .missingDate' in s,
 'complete record drilldown': 'qualityScope = .complete' in s,
 'quality scope filtering': 'case .missingUser: qualityMatches = missingUser' in s,
 'replacement priority buckets': 'Overdue 24+ months' in s and 'Overdue 12–23 months' in s,
 'planning queue export': 'private func exportPlanningQueue()' in s,
 'planning summary export': 'private func exportPlanningSummary()' in s,
 'existing four year policy retained': 'value: 4' in s,
 'no enterprise provider': 'import Jamf' not in s,
}
for name, passed in checks.items():
 print(('PASS' if passed else 'FAIL') + ': ' + name)
assert all(checks.values())
