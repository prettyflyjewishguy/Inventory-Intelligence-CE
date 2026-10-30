![Inventory Intelligence CE banner](Assets/github-banner.png)

# Inventory Intelligence CE

**Understand your inventory. Plan what's next.**

Turn a local inventory CSV into a clear picture of device health, replacement priorities, and future hardware spending. Inventory Intelligence CE is a native macOS application built with SwiftUI for teams that want actionable lifecycle insights without connecting to a device-management service.

![Release](https://img.shields.io/badge/release-1.0.0%20RC1-0a9b80) ![Platform](https://img.shields.io/badge/platform-macOS-202c3a) ![Architecture](https://img.shields.io/badge/architecture-Apple%20Silicon-202c3a) ![Interface](https://img.shields.io/badge/interface-SwiftUI-0a9b80) ![Distribution](https://img.shields.io/badge/distribution-source%20RC-202c3a)

<img src="Assets/app-icon-512.png" alt="Inventory Intelligence CE app icon" width="104">

> **Release status:** Version **1.0.0 RC1** is a source release candidate. It is not a signed or notarized macOS installer. See [Release notes](Docs/RELEASE_NOTES.md) and [License and publication](#license-and-publication).

## Take a look

A familiar macOS sidebar, focused dashboards, searchable inventory, and planning views designed to turn raw device records into useful decisions.

| Dashboard | Serial Lookup |
| :---: | :---: |
| ![Dashboard showing inventory and lifecycle summary](Docs/Assets/Screenshots/01-dashboard.png) | ![Serial Lookup showing device details](Docs/Assets/Screenshots/02-serial-lookup.png) |
| **Fleet overview and lifecycle health** | **Find and inspect individual devices** |

| Inventory Reports | Lifecycle Analytics |
| :---: | :---: |
| ![Inventory Reports showing searchable records](Docs/Assets/Screenshots/03-inventory-reports.png) | ![Lifecycle Analytics showing device trends](Docs/Assets/Screenshots/04-lifecycle-analytics.png) |
| **Search, filter, and export inventory** | **Understand aging and replacement trends** |

| Replacement Planning | Device Intelligence & Budget |
| :---: | :---: |
| ![Replacement Planning showing prioritized devices](Docs/Assets/Screenshots/05-replacement-planning.png) | ![Device Intelligence and Budget showing forecasts](Docs/Assets/Screenshots/06-device-intelligence-budget.png) |
| **Build an actionable replacement queue** | **Configure policies and forecast costs** |

## What you can do

- **Dashboard:** Review inventory totals, lifecycle status, unknown dates, and upcoming replacement demand.
- **Serial Lookup:** Find imported devices by serial number and inspect their details.
- **Inventory Reports:** Search, filter, paginate, and export inventory records.
- **Lifecycle Analytics:** Explore device age, model distribution, data completeness, and replacement windows.
- **Replacement Planning:** Identify overdue devices, prioritize review, and plan future replacements.
- **Device Intelligence & Budget:** Set model-specific lifecycle and estimated replacement-cost policies, then forecast spending over 6, 12, 18, and 24 months.
- **Native macOS workflow:** Import CSVs from **File → Import Inventory CSV…**, export from the **File** menu, and access built-in documentation from **Help**.

### Community vs. Organization / Enterprise

| Capability | Community Edition 1.0.0 RC1 | Separate Organization / Enterprise Edition |
| --- | --- | --- |
| Local CSV-based inventory analysis | **Yes** | Separate workflow; not asserted here |
| Lifecycle analytics | **Yes** | Existing lifecycle functionality |
| Configurable model-specific lifecycle policies | **Yes** | Proposed for a future Enterprise update |
| Replacement Planning tab | **Yes** | Proposed for a future Enterprise update |
| Replacement budget forecasting | **Yes** | Proposed for a future Enterprise update |
| Direct Apple Business Manager integration | **No** | **Yes** |
| Direct Jamf Pro integration | **No** | **Yes** |
| Microsoft Intune / other MDM integration | **No** | Not claimed |

**CE operates on CSV files you explicitly import.** It does **not** authenticate to Apple Business Manager (ABM), Jamf Pro, Microsoft Intune, or another MDM platform. Direct ABM and Jamf inventory integration has been implemented in the separate Enterprise product; that integration is **not part of CE**.

## Get started

### Requirements

- An **Apple Silicon Mac**.
- **macOS 14 or later** (project-stated minimum; compatibility has not been independently verified across all supported releases).
- Xcode Command Line Tools and an available macOS SDK.

This repository provides **source code and a local build script**, not a prebuilt signed application.

1. Download or clone the repository and open Terminal in the repository directory.
2. Build the application:

   ```bash
   zsh scripts/build_on_mac.zsh
   ```

3. Launch the built app:

   ```bash
   open "dist/Inventory Intelligence CE.app"
   ```

4. Choose **File → Import Inventory CSV…** and select your inventory file, or start with one of the included synthetic samples.

> **Build note:** Locally built applications are **unsigned and not notarized**. The approved Revision 9 iconset is used to generate the application icon during the build. See the [Help guide](Docs/HELP.md) for usage details.

### Prepare your CSV

At minimum, include these columns:

| Column | Purpose |
| --- | --- |
| `Serial` | Device identifier |
| `Model` | Device model used for lifecycle policy matching |

Recommended columns include `Assigned User` and `Date Added` in `YYYY-MM-DD` format. The **Date Added** field is the lifecycle reference date in the imported data; do not assume it is a verified purchase date. See the [Help guide](Docs/HELP.md) for supported mapping and validation details.

Included synthetic datasets:

- `sample_inventory_1000.csv`
- `sample_inventory_5000.csv`
- `sample_inventory_10000.csv`

**Validation status:** The 5,000-device dataset was used for visual and numerical review. The 10,000-device performance benchmark and final export reconciliation have **not** been confirmed.

## Privacy and data handling

Inventory Intelligence CE processes **CSV files you select locally**. It does not log into or synchronize data from ABM or MDM services. Inventory exports may contain names, serial numbers, and other identifying details; inspect them before sharing and use the included synthetic samples for public demonstrations.

## Current limitations

- **CSV-only:** No live ABM, Jamf Pro, Intune, or other MDM connector in CE.
- **Source release candidate:** No signed or notarized installer is provided.
- **Forecasts are estimates:** Replacement costs come from configurable policies, not supplier quotes or purchase orders.
- **Data quality matters:** Missing or ambiguous dates and device models can affect lifecycle classifications and forecasts.
- **Validation scope:** The 10,000-device performance benchmark and final export reconciliation remain outstanding.

## Documentation

- [User guide](Docs/HELP.md)
- [Release notes](Docs/RELEASE_NOTES.md)
- [Contributing](CONTRIBUTING.md)
- [Publication notice](Docs/PUBLICATION_NOTICE.md)

### Open the README from the app

Use **Help → View README in Web Browser** to open the bundled browser-friendly README. To configure the build to point to this GitHub repository instead, run:

```bash
REPOSITORY_README_URL="https://github.com/prettyflyjewishguy/Inventory-Intelligence-CE#readme" zsh scripts/build_on_mac.zsh
```

## License and publication

**No open-source license is granted with this source release candidate.** Rights to redistribute the code and artwork, including artwork also used by the separate Enterprise application, have not been established. Review the [publication notice](Docs/PUBLICATION_NOTICE.md) before redistributing or reusing any part of this repository. Do not describe the project as MIT-licensed unless the necessary rights have been confirmed and an appropriate license has been added.

Inventory Intelligence CE is not endorsed by Apple, Jamf, Microsoft, or other vendors.
