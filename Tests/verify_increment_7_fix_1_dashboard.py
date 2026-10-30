#!/usr/bin/env python3
"""Increment 7 Fix 1: verify all primary lifecycle counts use one policy-aware classifier.
Source-contract test; native macOS compilation and runtime testing remain required.
"""
from pathlib import Path
import re
s = (Path(__file__).resolve().parents[1] / "Sources/InventoryIntelligenceApp.swift").read_text()
dashboard = s.split('switch screen ?? .dashboard {', 1)[1].split('case .dashboard:', 1)[1].split('case .lookup:', 1)[0]
assert 'dashboardMetric("Replacement review", analyticsCount(.review)' in dashboard
assert 'dashboardMetric("Unknown dates", analyticsCount(.unknown)' in dashboard
assert 'reportMetric("Within window", analyticsCount(.withinWindow)' in dashboard
assert 'Lifecycle.yearsSince(' not in dashboard
assert 'case .review: return policy.label(for: device) == "Review replacement"' in s
assert 'case .withinWindow: return policy.label(for: device) == "Within lifecycle window"' in s
assert 'case .unknown: return policy.label(for: device) == "Unknown"' in s
assert 'case .review: statusMatches = policy.label(for: device) == "Review replacement"' in s
assert 'reportMetric("Review", analyticsCount(.review)' in s
assert 'reportMetric("Review now", reviewCandidates.count' in s
review = s.split('private var reviewCandidates:', 1)[1].split('private var forecastCandidates:', 1)[0]
assert 'policy.label(for:' in review
assert 'reach their configured lifecycle threshold' in s
assert 'reach four years within that period' not in s
assert 'Estimated Four-Year Date' not in s
print("Increment 7 Fix 1 Dashboard shared-policy source-contract checks passed")
