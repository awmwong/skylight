#!/usr/bin/env bash
# Build a Release Skylight.app, ad-hoc sign it, and zip it for local
# distribution. No notarization: this is a personal-use build, not for the
# App Store or for distributing to other machines' Gatekeeper checks.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(git describe --tags --always 2>/dev/null || echo dev)"

xcodegen generate
xcodebuild -project Skylight.xcodeproj -scheme Skylight -configuration Release \
  -derivedDataPath build -destination 'platform=macOS' build

APP="build/Build/Products/Release/Skylight.app"
if [ ! -d "$APP" ]; then
  echo "error: build did not produce $APP" >&2
  exit 1
fi

# --options runtime keeps the hardened runtime the Release build enables;
# a bare re-sign would silently strip it. No --deep: Xcode already signed
# nested code, and --deep re-signs it incorrectly.
codesign --force --options runtime --sign - "$APP"

mkdir -p dist
ZIP_PATH="dist/Skylight-${VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP" "$ZIP_PATH"

echo "$ZIP_PATH"
