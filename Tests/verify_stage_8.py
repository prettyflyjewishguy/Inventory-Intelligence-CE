from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'Sources/InventoryIntelligenceApp.swift').read_text()
checks={
 'persistent local templates':'UserDefaults.standard.set(data, forKey: savedViewsKey)' in s,
 'template loading':'JSONDecoder().decode([SavedReportView].self, from: data)' in s,
 'template removal persists':'savedReportViews.removeAll { $0.id == id }\n                                            persistSavedViews()' in s,
 'existing forecast windows':'case six = 6, twelve = 12, eighteen = 18, twentyFour = 24' in s,
 'no parser changes':'enum CSVParser' in s,
}
for name,passed in checks.items(): print(('PASS' if passed else 'FAIL')+': '+name)
assert all(checks.values())
