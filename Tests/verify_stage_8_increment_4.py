from pathlib import Path
s=(Path(__file__).parents[1]/'Sources/InventoryIntelligenceApp.swift').read_text()
checks={
 'lookup empty state':'ContentUnavailableView("Find a device"' in s,
 'paged report results':'pagedDeviceRows(reportRows, page: $reportPage' in s,
 'paged lookup results':'pagedDeviceRows(matches, page: $lookupPage' in s,
 'paged planning review':'pagedDeviceRows(reviewCandidates, page: $planningReviewPage' in s,
 'paged upcoming':'pagedDeviceRows(forecastCandidates, page: $planningUpcomingPage' in s,
 'page size controls':'Text("100").tag(100)' in s,
 'full filtered export':'exportCSV(reportRows, suggestedName:' in s,
 'export completion':'reportNotice = "Exported ' in s,
}
for k,v in checks.items(): print(('PASS' if v else 'FAIL')+': '+k)
assert all(checks.values())
