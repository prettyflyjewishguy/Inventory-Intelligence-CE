#!/usr/bin/env python3
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
source = (root / "Sources/InventoryIntelligenceApp.swift").read_text()
core = source.split("struct ContentView: View {")[0]
assert hashlib.sha256(core.encode()).hexdigest() == "1716aeb1f71236ce04d97073f7eaffa9f98919c5fd8c98f1bc79f0417163b267", "Protected parser/model/lifecycle/provider core changed"
for item in ['private var hasImportedSource', 'private var inventorySummary', 'feedbackPanel("Inventory ready"', 'feedbackPanel("Get started with a CSV"', 'Showing all', 'matching', 'Source:', 'Label("Import CSV", systemImage: "doc.badge.plus")']:
    assert item in source, f"Missing UI Refinement 3 presentation: {item}"
print("PASS: protected core SHA-256 matches frozen UI Refinement 2")
print("PASS: contextual UI presentation checks")
