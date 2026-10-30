from pathlib import Path
s = (Path(__file__).resolve().parents[1] / 'Sources/InventoryIntelligenceApp.swift').read_text()
for token in ['@State private var selectedDevice: DeviceRecord?', '.sheet(item: $selectedDevice)', 'DeviceDetailsSheet(device: device', 'NSPasteboard.general.setString(device.serial', 'Imported Reference Date', 'Lifecycle Assessment', 'View details for serial']:
    assert token in s, token
print('UI Refinement 4 Stage 1 source checks passed')
