from pathlib import Path
s=Path(__file__).resolve().parents[1].joinpath("Sources/InventoryIntelligenceApp.swift").read_text()
for marker in ("private var analyticsOverview", "private var analyticsBreakdown", "Understanding lifecycle status", "selectReportFilter(filter)", "Lifecycle.label(device.dateAdded)"):
    assert marker in s, marker
assert 'private func analyticsCount' in s
print("Stage 3 presentation assertions passed")
