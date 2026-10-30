# Community Edition 1.0.0 — Source Release Candidate

Derived from the approved Stage 8 Increment 8 source without changing the lifecycle calculation, CSV parsing, report generation, or planning engines.

## Release packaging changes
- Native macOS File menu for CSV import and existing exports.
- Native Help menu opening a bundled, searchable-by-scrolling user guide.
- GitHub banner, icon PNG, macOS iconset, and refreshed documentation.
- App bundle version 1.0.0 and community bundle identifier.

## Status
Release-candidate packaging only. Native macOS compilation and manual menu interaction require validation. Existing Stage 8 frozen reference remains unchanged.

### Revision 6
- Fixed offline README browser action by bundling rendered HTML and image assets.
- Made icon generation mandatory and registered AppIcon.icns in Info.plist.
- Rebuilt the iconset directly from the original Enterprise artwork.
- Simplified GitHub README to native Markdown with valid image links.
