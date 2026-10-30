#!/usr/bin/env python3
from pathlib import Path
import difflib
root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/InventoryIntelligenceApp.swift').read_text()
assert 'Label("Import CSV", systemImage: "doc.badge.plus")' in source
assert '.labelStyle(.titleAndIcon)' in source
assert '.help("Import device inventory from a CSV file")' in source
assert 'importing = true' in source
assert '.fileImporter(isPresented: $importing' in source
exec(compile((root / 'Tests/verify_ui_refinement.py').read_text(), 'verify_ui_refinement.py', 'exec'))
print('PASS: UI Refinement 2 toolbar action and help text present')
