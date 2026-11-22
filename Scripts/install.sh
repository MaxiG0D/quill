#!/usr/bin/env bash
# Checks, builds and installs Quill, on exactly the targets named.
# Usage: Scripts/install.sh mac|duo|ipad [...]    e.g. Scripts/install.sh mac duo
# Device targets are found by name, case-insensitive: "duo" matches "iPhone Duo".
# A device must be unlocked and reachable. Nothing is installed if a check fails.
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -gt 0 ] || { echo "Name a target: mac, duo or ipad." >&2; exit 2; }

Scripts/check.sh

derived="$(mktemp -d)"
trap 'rm -rf "$derived"' EXIT
build() {
  xcodebuild build -project Quill.xcodeproj -scheme Quill -configuration Debug \
    -destination "$1" -derivedDataPath "$derived/$2" -allowProvisioningUpdates -quiet
}

for target in "$@"; do
  case "$target" in
    mac)
      build "generic/platform=macOS" mac
      osascript -e 'tell application "Quill" to quit' 2>/dev/null || true
      sleep 1
      rm -rf /Applications/Quill.app
      cp -R "$derived/mac/Build/Products/Debug/Quill.app" /Applications/Quill.app
      open /Applications/Quill.app
      ;;
    duo|ipad)
      [ "$target" = duo ] && pattern="duo" || pattern="ipad"
      [ -d "$derived/ios" ] || build "generic/platform=iOS" ios
      json="$derived/devices.json"
      xcrun devicectl list devices --json-output "$json" >/dev/null
      id="$(python3 - "$json" "$pattern" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
hits = [d for d in devices if sys.argv[2] in d["deviceProperties"]["name"].lower() and d.get("hardwareProperties",{}).get("reality","physical") != "simulated"]
print(hits[0]["identifier"] if len(hits) == 1 else "")
PY
)"
      [ -n "$id" ] || { echo "No single device matches '$pattern'." >&2; exit 1; }
      xcrun devicectl device install app --device "$id" "$derived/ios/Build/Products/Debug-iphoneos/Quill.app"
      xcrun devicectl device process launch --device "$id" com.maxig0d.quill || echo "Installed. Unlock the device and open Quill."
      ;;
    *) echo "Unknown target '$target'." >&2; exit 2 ;;
  esac
done
