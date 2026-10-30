# Stage 8 Increment 6 — Compilation Fix 1

Fixes a source-generation error where eight `device.hardware` rows were inserted into the Reporting Workflows help sheet, which has no `device` binding. These fields now appear conditionally in the device details sheet, where `device` is in scope. The report guide remains unchanged. No policy or budget calculations were modified.

Run `python3 Tests/verify_increment_6_scope_fix.py`, then `zsh scripts/build_on_mac.zsh` on macOS. SwiftUI compilation and full regression testing require validation on macOS; they have not been run here.

Increment 5 remains the approved baseline. This is an Increment 6 development candidate, not a promoted release.
