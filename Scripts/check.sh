#!/usr/bin/env bash
# Everything that can break a push, in one command: the package tests, the relay tests,
# and Debug builds for macOS and iOS (which catch what only one platform's compiler sees).
# Usage: Scripts/check.sh [--quick]   (--quick skips the app builds)
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n== %s\n' "$1"; }

step "Relay tests"
(cd Relay && { [ -d node_modules ] || npm ci --silent; } && npm test --silent)

step "QuillKit tests"
(cd QuillKit && swift test)

[ "${1:-}" = "--quick" ] && exit 0

build() {
  xcodebuild build -project Quill.xcodeproj -scheme Quill -configuration Debug \
    -destination "$1" -allowProvisioningUpdates -quiet
}
step "Build: macOS"
build "generic/platform=macOS"
step "Build: iOS (app, notification extension, Live Activity widget)"
build "generic/platform=iOS"

printf '\nAll checks passed.\n'
