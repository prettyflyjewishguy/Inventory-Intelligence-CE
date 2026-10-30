from pathlib import Path
s = Path('Sources/InventoryIntelligenceApp.swift').read_text()
report = s.split('.sheet(isPresented: $showReportGuide)',1)[1].split('.sheet(isPresented: $showExportOptions)',1)[0]
assert 'device.hardware' not in report, 'Device fields must not be used in reporting guide scope'
details = s.split('private struct DeviceDetailsSheet: View',1)[1].split('private struct ',1)[0]
for field in ('processor','memoryGB','storageGB','osVersion','enrollmentStatus','managementPlatform','lastInventoryUpdate','assetTag'):
    assert f'device.hardware.{field}' in details, f'Missing detail field: {field}'
assert 'Text("Hardware & Management")' in details
print('PASS: enriched attributes are scoped to DeviceDetailsSheet')
