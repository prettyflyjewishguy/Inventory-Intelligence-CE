#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Compiles production DeviceRecord, Lifecycle, and PlanningPolicy with Foundation only.
# Requires Swift toolchain; does not compile SwiftUI views on Linux.
swiftc Tests/PolicyCoreUnderTest.swift Tests/Increment8PolicyRegression.swift -o /tmp/ce-increment8-regression
/tmp/ce-increment8-regression sample_inventory_1000.csv
/tmp/ce-increment8-regression sample_inventory_5000.csv
/tmp/ce-increment8-regression sample_inventory_10000.csv
