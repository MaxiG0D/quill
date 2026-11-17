#!/bin/bash
# Builds, notarizes and publishes a Mac release of Quill that installed copies update to.
#
#   Scripts/release-mac.sh setup      once: creates the update signing key in the Keychain
#                                     and writes its public half into App/Info.plist
#   Scripts/release-mac.sh 0.2.0      builds 0.2.0, notarizes it, and publishes a GitHub
#                                     release holding Quill-0.2.0.zip and appcast.xml
#
# Needs a Developer ID Application certificate, `gh` signed in, and a notarytool profile:
#   xcrun notarytool store-credentials quill-notary
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="MaxiG0D/quill"
TEAM="NZN9M2VV5J"
PROFILE="quill-notary"
OUT="build/release"
SPARKLE_BIN="$OUT/SourcePackages/artifacts/sparkle/Sparkle/bin"

resolve_sparkle() {
  [ -x "$SPARKLE_BIN/generate_keys" ] && return
  xcodebuild -resolvePackageDependencies -project Quill.xcodeproj -scheme Quill -derivedDataPath "$OUT" >/dev/null
}

if [ "${1:-}" = "setup" ]; then
  resolve_sparkle
  "$SPARKLE_BIN/generate_keys" >/dev/null
  KEY=$("$SPARKLE_BIN/generate_keys" -p)
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $KEY" App/Info.plist
  echo "Public key written to App/Info.plist. Commit it. The private key stays in your Keychain."
  exit 0
fi

VERSION="${1:?usage: release-mac.sh <version> | setup}"
BUILD=$(git rev-list --count HEAD)
KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" App/Info.plist)
[ -n "$KEY" ] || { echo "Run Scripts/release-mac.sh setup first." >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Commit your changes first." >&2; exit 1; }

rm -rf "$OUT/Quill.xcarchive" "$OUT/export" "$OUT/updates"
mkdir -p "$OUT/updates"

xcodebuild archive -project Quill.xcodeproj -scheme Quill \
  -destination 'generic/platform=macOS' -archivePath "$OUT/Quill.xcarchive" \
  -derivedDataPath "$OUT" -allowProvisioningUpdates \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" | tail -n 5

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>$TEAM</string>
	<key>signingStyle</key>
	<string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$OUT/Quill.xcarchive" -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates | tail -n 5

ZIP="$OUT/updates/Quill-$VERSION.zip"
ditto -c -k --keepParent "$OUT/export/Quill.app" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$OUT/export/Quill.app"
rm "$ZIP"
ditto -c -k --keepParent "$OUT/export/Quill.app" "$ZIP"

"$SPARKLE_BIN/generate_appcast" "$OUT/updates" \
  --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
  --maximum-versions 1 --maximum-deltas 0

gh release create "v$VERSION" "$ZIP" "$OUT/updates/appcast.xml" --repo "$REPO" \
  --title "Quill $VERSION" --generate-notes
echo "Quill $VERSION is out. Installed copies find it on their next check."

# SCREENSHOTS=1 also retakes the README images from this build's sources, ready to commit.
if [ "${SCREENSHOTS:-}" = "1" ]; then
  Scripts/screenshots.sh
  echo "README images updated; review and commit them."
fi
