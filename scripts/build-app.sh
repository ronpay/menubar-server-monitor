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
VERSION="0.1.0"
BUILD="1"

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

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
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
