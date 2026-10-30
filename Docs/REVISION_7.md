# Revision 7 — Banner and icon assets

- Replaced the GitHub/README banner with a restrained charcoal-and-green design.
- Rebuilt all ten iconset PNGs from the original Enterprise artwork with transparent backgrounds and transparent-edge cleanup.
- Added a build-time check that the generated AppIcon.icns is present and Info.plist references it.
- No inventory, lifecycle, reporting, menu, or Help logic changed.

**macOS Dock note:** The original artwork has light silver/white highlights in the illustrated laptop and magnifier. Those are not an external border. If macOS applies a white plate around the whole icon, that may be a system icon treatment or a cached installed app; this package cannot guarantee macOS will not apply system styling.

**Verification:** Assets generated and inspected programmatically on Linux; native macOS build and Dock display have not been tested here.
