from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'Sources/InventoryIntelligenceApp.swift').read_text()
checks = {
    'model distribution': 'private var modelDistribution:' in s,
    'model drilldown': 'reportModel = item.name' in s,
    'data quality dashboard': 'private var analyticsQualityView:' in s,
    'forecast outlook': 'private var analyticsPlanningView:' in s,
    '6/12/18/24 horizons': 'ForEach(ForecastWindow.allCases) { window in' in s,
    'analytics integration': 'analyticsModelsView\n                            analyticsQualityView\n                            analyticsPlanningView' in s,
    'saved report persistence retained': 'UserDefaults.standard.set(data, forKey: savedViewsKey)' in s,
}
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
assert all(checks.values())
