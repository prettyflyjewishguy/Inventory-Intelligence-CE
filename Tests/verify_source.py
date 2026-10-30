#!/usr/bin/env python3
"""Portable source sanity checks; not a substitute for macOS build and UI tests."""
from pathlib import Path
import re
source = (Path(__file__).resolve().parents[1] / "Sources/InventoryIntelligenceApp.swift").read_text()
checks = {
 "InventoryStore declared": "final class InventoryStore" in source,
 "importCSV declared": "func importCSV(_ url: URL)" in source,
 "explicit caught-error state": "self.error = error.localizedDescription" in source,
 "Screen navigation declared": "enum Screen:" in source,
 "four screens declared": all(x in source for x in ['case dashboard', 'lookup = "Serial Lookup"', 'reports = "Inventory Reports"', 'analytics = "Lifecycle Analytics"']),
 "no enterprise imports": not re.search(r"(?i)veeam|jamf.*token|client.secret|api[_-]?key\s*=",source),
}
for name, ok in checks.items(): print(("PASS" if ok else "FAIL") + ": " + name)
if not all(checks.values()): raise SystemExit(1)
