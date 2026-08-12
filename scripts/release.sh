#!/usr/bin/env bash
# Build a Release Skylight.app, install it to /Applications, and zip it for
# local backup. No notarization: this is a personal-use build, not for the
# App Store or for distributing to other machines' Gatekeeper checks.
#
# Pass --no-install to only build and zip (skip the /Applications copy).
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --no-install) INSTALL=0 ;;
    *) echo "error: unknown argument '$arg'" >&2; exit 1 ;;
  esac
done

VERSION="$(git describe --tags --always 2>/dev/null || echo dev)"
INSTALL_PATH="/Applications/Skylight.app"

xcodegen generate
xcodebuild -project Skylight.xcodeproj -scheme Skylight -configuration Release \
  -derivedDataPath build -destination 'platform=macOS' build

APP="build/Build/Products/Release/Skylight.app"
if [ ! -d "$APP" ]; then
  echo "error: build did not produce $APP" >&2
  exit 1
fi

# No re-sign here: xcodebuild already signed the app with the project's
# stable identity and the hardened runtime. Re-signing ad-hoc would strip
# both and reset the app's Screen Recording grant.

mkdir -p dist
ZIP_PATH="dist/Skylight-${VERSION}.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP" "$ZIP_PATH"
echo "zip: $ZIP_PATH"

if [ "$INSTALL" -eq 1 ]; then
  # TCC only keeps a Screen Recording grant for an app in a stable location,
  # not a build folder, so run the app from /Applications. The stable signing
  # identity means overwriting keeps the existing grant — no re-prompt. Quit
  # a running copy first so the running binary isn't replaced under it.
  osascript -e 'quit app "Skylight"' >/dev/null 2>&1 || true
  rm -rf "$INSTALL_PATH"
  cp -R "$APP" "$INSTALL_PATH"
  echo "installed: $INSTALL_PATH"
fi
