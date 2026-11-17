#!/bin/bash
# Builds "Quill Release.app" (the release applet) at the repository root. Open it to publish a
# Mac release or retake the README screenshots without the terminal.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/Quill Release.app"
BUILD="/private/tmp/quill-release-app.noindex"   # outside the repo and Spotlight

rm -rf "$BUILD"
mkdir -p "$BUILD/Quill Release.app/Contents/MacOS" "$BUILD/Quill Release.app/Contents/Resources" "$BUILD/AppIcon.iconset"
STAGED="$BUILD/Quill Release.app"

swiftc -parse-as-library -swift-version 5 -O -target arm64-apple-macosx14.0 \
  -module-cache-path "$BUILD/module-cache" \
  Scripts/QuillRelease/main.swift -o "$STAGED/Contents/MacOS/QuillRelease"

ICON="App/Assets.xcassets/AppIcon.appiconset/mac-1024.png"
for size in 16 32 128 256 512; do
  sips -z $size $size "$ICON" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$ICON" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$STAGED/Contents/Resources/AppIcon.icns"

cat > "$STAGED/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>QuillRelease</string>
  <key>CFBundleIdentifier</key><string>com.maxig0d.quill.release-tool</string>
  <key>CFBundleName</key><string>Quill Release</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# An Apple Development identity survives rebuilds, so macOS remembers the Screen Recording
# permission the screenshots need instead of asking again after every build.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ { print $2; exit }')"
codesign --force --sign "${IDENTITY:--}" "$STAGED"

rm -rf "$APP"
ditto --noextattr --noqtn "$STAGED" "$APP"
xattr -cr "$APP" 2>/dev/null || true
rm -rf "$BUILD"
echo "Built $APP"
