#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "ERROR: macOS required for SwiftUI compilation."
  exit 1
fi
command -v swiftc >/dev/null || { print -u2 "ERROR: Swift compiler not installed. Install Xcode Command Line Tools."; exit 1; }
APP="${PWD}/dist/Inventory Intelligence CE.app"
TMP="${PWD}/dist/.InventoryIntelligenceCE-build-$$.app"
mkdir -p "${PWD}/dist"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/Contents/MacOS" "$TMP/Contents/Resources"
print "Checking Swift syntax..."
swiftc -frontend -parse Sources/InventoryIntelligenceApp.swift
print "Compiling macOS app..."
swiftc -O -parse-as-library -target arm64-apple-macos14.0 -framework SwiftUI -framework UniformTypeIdentifiers Sources/InventoryIntelligenceApp.swift -o "$TMP/Contents/MacOS/InventoryIntelligenceCommunity"
cat > "$TMP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>InventoryIntelligenceCommunity</string>
<key>CFBundleIdentifier</key><string>org.inventoryintelligence.community</string>
<key>CFBundleName</key><string>Inventory Intelligence CE</string>
<key>CFBundleDisplayName</key><string>Inventory Intelligence CE</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>100</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Bundle the actual README HTML and Help document so browser actions work offline.
cp Docs/HELP.md "$TMP/Contents/Resources/HELP.md"
cp Docs/README_BROWSER.html "$TMP/Contents/Resources/README.html"
mkdir -p "$TMP/Contents/Resources/Assets"
cp Assets/github-banner.png Assets/app-icon-512.png "$TMP/Contents/Resources/Assets/"

# Revision 9: use corrected, fully opaque artwork to avoid macOS gray backing plate.
# Original Enterprise artwork is retained in Assets/enterprise-original-icon.png.
# Fail visibly if iconutil fails.
# Never silently ship an app with the generic macOS icon.
rm -f Assets/AppIcon.icns
iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
[[ -s Assets/AppIcon.icns ]] || { print -u2 "ERROR: Icon generation failed"; exit 1; }
cp Assets/AppIcon.icns "$TMP/Contents/Resources/AppIcon.icns"
# Verify the icon file and bundle metadata before installation.
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$TMP/Contents/Info.plist" | grep -qx "AppIcon.icns"
[[ -s "$TMP/Contents/Resources/AppIcon.icns" ]] || { print -u2 "ERROR: AppIcon.icns missing"; exit 1; }

# Optional: point the README menu at a real GitHub repository instead of local HTML.
if [[ -n "${REPOSITORY_README_URL:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :CERepositoryReadmeURL string ${REPOSITORY_README_URL}" "$TMP/Contents/Info.plist"
fi

# Only replace prior app after successful compile.
rm -rf "$APP"
mv "$TMP" "$APP"
trap - EXIT
print "SUCCESS: $APP"
print "Dock still shows old artwork? Quit the app, remove the older installed copy, and relaunch this exact dist app. macOS may cache icons independently of the iconset."
print "Unsigned local build of the 1.0.0 source release candidate; not notarized."
