# Revision 9 — Dock icon correction

The Enterprise original icon is preserved at `Assets/enterprise-original-icon.png`.

**Cause addressed:** the previous icon has transparent outside corners. Modern macOS may apply a gray backing plate to legacy transparent app icons. Rather than removing the green background (Revision 8), Revision 9 preserves the full Enterprise illustration and fills only the previously transparent corner area with extended colors from the original perimeter. The icon source is fully opaque; macOS can apply its native rounded-square mask without a gray transparency backing plate.

`Assets/app-icon-source-corrected.png` is the corrected master; `Assets/AppIcon.iconset` contains all ten generated PNG representations. `Assets/github-banner.png`, README, File menu, Help, and application source were copied unchanged from Revision 7.

**Verification performed:** source master and ten PNG sizes checked; alpha channel is fully opaque; light/dark rounded-mask preview generated. **Not verified:** final Dock appearance on macOS.
