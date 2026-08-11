#!/usr/bin/env bash
# Generate the project, build Debug, and launch the app.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
xcodebuild -project Skylight.xcodeproj -scheme Skylight -configuration Debug \
  -derivedDataPath build -destination 'platform=macOS' -quiet build

APP="build/Build/Products/Debug/Skylight.app"
echo "Launching $APP"
open "$APP"
