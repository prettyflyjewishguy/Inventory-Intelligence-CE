# Inventory Intelligence CE

## Getting started
1. Choose **File → Import Inventory CSV…** (or use the Import CSV toolbar button).
2. Select a UTF-8 CSV containing **Serial** and **Model** columns. Optional columns include Assigned User, Date Added, Processor, Memory GB, Storage GB, OS Version, Enrollment Status, Management Platform, Last Inventory Update, and Asset Tag.
3. Explore Dashboard, Serial Lookup, Inventory Reports, Lifecycle Analytics, Replacement Planning, and Device Intelligence & Budget.

## CSV requirements
- Required headers: `Serial`, `Model` (aliases `Serial Number`, `Model Name`).
- Recommended: `Assigned User`, `Date Added` (YYYY-MM-DD).
- Serial numbers must be unique and nonempty. CSV quoting is supported.
- Reference dates are imported data; **not verified purchase dates**.
- Imports replace the current in-memory inventory; save your source CSV separately.

## Navigation
- **Dashboard**: policy-aware counts, replacement review, unknown dates, and overview cards.
- **Serial Lookup**: type all or part of a serial; empty search does not list the entire fleet.
- **Inventory Reports**: search, filter, sort, page through results, and export.
- **Lifecycle Analytics**: distribution, forecasts, model analytics, and paginated devices.
- **Replacement Planning**: overdue priorities and upcoming replacement candidates.
- **Device Intelligence & Budget**: change default/model-specific lifecycle years and estimated replacement costs.

## File menu
- **Import Inventory CSV…** opens the file picker.
- **Export Filtered CSV…** and **Export Excel Workbook…** use the current Inventory Reports filters. They export the entire matching result set, not only the visible page.
- **Export Data Quality CSV…** exports incomplete records.
- **Export Replacement Queue CSV…** exports replacement-review candidates.

## Lifecycle and budgeting
The configured policy applies to Dashboard, Reports, Analytics, Planning, and exports. Replacement review is a planning classification, not a purchasing directive. Forecast windows are cumulative; do not sum their totals. Missing reference dates are excluded from dated forecasts.

## Reports
Excel workbooks include Report Results, Full Inventory, Replacement Review, Data Quality, Lifecycle Policy, and Summary. CSV exports are UTF-8. Validate outputs before making purchasing decisions.

## Troubleshooting
- **Missing required columns**: verify Serial and Model headers.
- **Duplicate serial**: remove duplicate or blank serial values.
- **Invalid dates**: use YYYY-MM-DD or ISO 8601.
- **Unexpected counts**: check model-specific lifecycle settings and missing dates.
- **No rows after filtering**: clear filters and search.

## Privacy and limitations
CSV data stays on this Mac unless you manually export/share it. This release does not connect to Jamf, ABM, Intune, or any cloud service. It is distributed as source; locally compiled apps are unsigned unless signed separately.

## About
Inventory Intelligence CE 1.0.0 source release candidate. macOS 14 or later; Apple Silicon build script. Independent community project; not endorsed by device-management vendors.
