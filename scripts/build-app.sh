#!/usr/bin/env bash
# Builds ServerMonitor as a macOS .app bundle using SwiftPM (no Xcode).
# Usage:
#   ./scripts/build-app.sh            # release build
#   ./scripts/build-app.sh debug      # debug build

set -euo pipefail

CONFIG="${1:-release}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ServerMonitor"
APP_DIR="$PROJECT_ROOT/build/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BUNDLE_ID="com.servermonitor.app"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
ICON_SVG="$PROJECT_ROOT/assets/server-monitor-icon.svg"

cd "$PROJECT_ROOT"

echo "▶ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "Build product not found at $BIN_PATH" >&2
    exit 1
fi

echo "▶ Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_PATH" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

if [[ -f "$ICON_SVG" ]]; then
    ICON_WORK="$(mktemp -d "${TMPDIR:-/tmp}/servermonitor-icon.XXXXXX")"
    trap 'rm -rf "$ICON_WORK"' EXIT
    ICONSET="$ICON_WORK/AppIcon.iconset"
    mkdir -p "$ICONSET"

    sips -s format png "$ICON_SVG" --out "$ICON_WORK/source.png" >/dev/null
    while read -r size filename; do
        sips -z "$size" "$size" "$ICON_WORK/source.png" --out "$ICONSET/$filename" >/dev/null
    done <<'SIZES'
16 icon_16x16.png
32 icon_16x16@2x.png
32 icon_32x32.png
64 icon_32x32@2x.png
128 icon_128x128.png
256 icon_128x128@2x.png
256 icon_256x256.png
512 icon_256x256@2x.png
512 icon_512x512.png
1024 icon_512x512@2x.png
SIZES
    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key><true/>
    </dict>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS will run the unsigned bundle without quarantine pain.
echo "▶ Ad-hoc codesign"
codesign --force --sign - --timestamp=none --options=runtime "$APP_DIR" >/dev/null

echo "✓ Built $APP_DIR"
echo "  Launch with: open \"$APP_DIR\""
