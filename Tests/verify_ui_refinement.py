#!/usr/bin/env python3
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
source=(root/'Sources/InventoryIntelligenceApp.swift').read_text()
core=source.split('struct ContentView: View {')[0]
expected='1716aeb1f71236ce04d97073f7eaffa9f98919c5fd8c98f1bc79f0417163b267'
assert hashlib.sha256(core.encode()).hexdigest()==expected, 'Protected core differs from validated Fix 2'
for required in ['navigationSplitViewColumnWidth', 'GridRow', 'lifecycleBadge', 'Inventory Intelligence — Community Edition']:
    assert required in source, f'Missing UI element: {required}'
print('PASS: protected core byte-for-byte identical to Fix 2')
print('PASS: UI refinement elements present')
