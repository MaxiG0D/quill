#!/bin/bash
# Regenerates the README images and the social preview from the sample mailbox.
#
#   Scripts/screenshots.sh            everything
#   Scripts/screenshots.sh mac        docs/screenshots/hero.png and mac-dark.png
#   Scripts/screenshots.sh iphone     docs/screenshots/iphone.png
#   Scripts/screenshots.sh social     docs/social-preview.png (needs the Mac shot, taken if missing)
#
# iPhone: the app runs in an iOS simulator and `simctl io` takes the pictures.
# Mac: the app runs with -QuillSnapshot, which sizes the window to 1400x900 points and
# reports its window number; `screencapture -l` then captures that one window, with
# transparent rounded corners. It needs no window arranging, but it does need Screen
# Recording to be allowed for the app that runs this script (Terminal, or Claude).
# Framing (rounded corners, shadow, background) is Scripts/frame.swift, built here.
#
# Only the sample mailbox is shown, never real mail. Nothing is installed on a device.
set -euo pipefail

cd "$(dirname "$0")/.."
SIM_NAME="${SCREENSHOTS_SIMULATOR:-Harmony iPhone 18 Pro}"
WORK="build/screenshots"
mkdir -p "$WORK" docs/screenshots
TARGETS=("$@")
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(mac iphone social)

die() { echo "screenshots.sh: $*" >&2; exit 1; }
wrote() { echo "wrote $1 ($(sips -g pixelWidth -g pixelHeight "$1" | awk '/pixel/ {printf "%s ", $2}' | sed 's/ $//; s/ /x/'))"; }

APP_PID=""; BOOTED_BY_US=""; SIM_UDID=""
cleanup() {
  [ -z "$APP_PID" ] || kill "$APP_PID" 2>/dev/null || true
  if [ -n "$SIM_UDID" ]; then
    xcrun simctl status_bar "$SIM_UDID" clear 2>/dev/null || true
    xcrun simctl terminate "$SIM_UDID" com.maxig0d.quill 2>/dev/null || true
    [ -z "$BOOTED_BY_US" ] || xcrun simctl shutdown "$SIM_UDID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

build_frame() {
  mkdir -p "$WORK"
  swiftc -O Scripts/frame.swift -o "$WORK/frame" 2>&1 | grep -v '^$' || true
  [ -x "$WORK/frame" ] || die "could not build Scripts/frame.swift (is the Xcode command line toolchain installed?)"
}

shoot_mac() {
  local screen="$1" appearance="$2" out="$3"
  echo "building Quill for Mac…"
  xcodebuild build -project Quill.xcodeproj -scheme Quill -destination 'platform=macOS' \
    -derivedDataPath build/shots CODE_SIGNING_ALLOWED=NO -quiet >"$WORK/mac-build.log" 2>&1 \
    || { tail -n 20 "$WORK/mac-build.log" >&2; die "Mac build failed (log: $WORK/mac-build.log)"; }
  local bin="build/shots/Build/Products/Debug/Quill.app/Contents/MacOS/Quill"
  local ready="$WORK/window-number"
  rm -f "$ready"
  # Run the binary directly (not through `open`) so the process is ours and only ours is captured.
  "$bin" -QuillScreen "$screen" -QuillAppearance "$appearance" -QuillSnapshot "$ready" \
    -AppleLocale en_US -AppleLanguages "(en)" -ApplePersistenceIgnoreState YES \
    -SUEnableAutomaticChecks NO -SUAutomaticallyUpdate NO >/dev/null 2>&1 &
  APP_PID=$!
  for _ in $(seq 60); do [ -s "$ready" ] && break; kill -0 "$APP_PID" 2>/dev/null || die "Quill exited before its window was ready"; sleep 0.5; done
  [ -s "$ready" ] || die "Quill's window never became ready"
  screencapture -x -o -l "$(cat "$ready")" "$out" || die "screencapture failed; allow Screen Recording for this terminal"
  kill "$APP_PID" 2>/dev/null || true; wait "$APP_PID" 2>/dev/null || true; APP_PID=""
  # A denied Screen Recording permission yields a picture without the app's content: catch the tiny ones.
  [ "$(sips -g pixelWidth "$out" | awk '/pixel/ {print $2}')" -ge 2000 ] || die "window capture is the wrong size; check Screen Recording permission and that no dialog is open"
}

if [[ " ${TARGETS[*]} " == *" mac "* || " ${TARGETS[*]} " == *" social "* ]]; then
  build_frame
  shoot_mac thread light "$WORK/mac-thread-light.png"
  if [[ " ${TARGETS[*]} " == *" mac "* ]]; then
    "$WORK/frame" hero "$WORK/mac-thread-light.png" docs/screenshots/hero.png
    wrote docs/screenshots/hero.png
  fi
  if [[ " ${TARGETS[*]} " == *" mac "* ]]; then
    shoot_mac thread dark "$WORK/mac-thread-dark.png"
    "$WORK/frame" hero "$WORK/mac-thread-dark.png" docs/screenshots/mac-dark.png 1000
    wrote docs/screenshots/mac-dark.png
  fi
  if [[ " ${TARGETS[*]} " == *" social "* ]]; then
    "$WORK/frame" social "$WORK/mac-thread-light.png" App/Assets.xcassets/AppIcon.appiconset/mac-1024.png docs/social-preview.png
    wrote docs/social-preview.png
  fi
fi

if [[ " ${TARGETS[*]} " == *" iphone "* ]]; then
  [ -x "$WORK/frame" ] || build_frame
  SIM_UDID=$(xcrun simctl list devices available | awk -v n="$SIM_NAME" 'index($0, n " (") { match($0, /[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}/); print substr($0, RSTART, RLENGTH); exit }')
  [ -n "$SIM_UDID" ] || die "no simulator named '$SIM_NAME'. Install an iOS runtime in Xcode, or set SCREENSHOTS_SIMULATOR to an existing simulator's name. This script never creates simulators."
  echo "building Quill for $SIM_NAME…"
  xcodebuild build -project Quill.xcodeproj -scheme Quill -destination "platform=iOS Simulator,id=$SIM_UDID" \
    -derivedDataPath build/shots-ios CODE_SIGNING_ALLOWED=NO -quiet >"$WORK/ios-build.log" 2>&1 \
    || { tail -n 20 "$WORK/ios-build.log" >&2; die "iOS build failed (log: $WORK/ios-build.log)"; }
  if ! xcrun simctl list devices | grep "$SIM_UDID" | grep -q Booted; then
    BOOTED_BY_US=1
    xcrun simctl boot "$SIM_UDID"
  fi
  xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null
  xcrun simctl install "$SIM_UDID" build/shots-ios/Build/Products/Debug-iphonesimulator/Quill.app
  xcrun simctl status_bar "$SIM_UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""
  shots=()
  while read -r screen appearance; do
    xcrun simctl terminate "$SIM_UDID" com.maxig0d.quill 2>/dev/null || true
    xcrun simctl launch "$SIM_UDID" com.maxig0d.quill -QuillScreen "$screen" -QuillAppearance "$appearance" >/dev/null
    sleep 4
    xcrun simctl io "$SIM_UDID" screenshot --type=png "$WORK/phone-$screen-$appearance.png" >/dev/null 2>&1
    shots+=("$WORK/phone-$screen-$appearance.png")
  done <<'LIST'
inbox light
thread dark
compose light
LIST
  "$WORK/frame" iphone docs/screenshots/iphone.png "${shots[@]}"
  wrote docs/screenshots/iphone.png
fi
