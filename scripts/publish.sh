#!/usr/bin/env bash
# Publish a semver release: tag, build, create a GitHub release, and update
# the Homebrew tap. The version bump comes from the Conventional Commits
# since the last tag. Pass --major, --minor, or --patch to override it.
set -euo pipefail
cd "$(dirname "$0")/.."

TAP_REPO="awmwong/homebrew-tap"

BUMP=""
for arg in "$@"; do
  case "$arg" in
    --major|--minor|--patch) BUMP="${arg#--}" ;;
    *) echo "usage: scripts/publish.sh [--major|--minor|--patch]" >&2; exit 1 ;;
  esac
done

fail() { echo "error: $1" >&2; exit 1; }

[ -z "$(git status --porcelain)" ] || fail "the working tree is not clean"
[ "$(git branch --show-current)" = "main" ] || fail "not on main"
git fetch origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] \
  || fail "main is not in sync with origin/main"

# A release asset on a private repo is not downloadable through the cask URL.
VISIBILITY="$(gh repo view --json visibility -q .visibility)"
[ "$VISIBILITY" = "PUBLIC" ] || fail "the repo is $VISIBILITY; make it public first (see docs/RELEASING.md)"

scripts/preflight.sh

xcodegen generate
xcodebuild -project Skylight.xcodeproj -scheme Skylight \
  -derivedDataPath build -destination 'platform=macOS' -quiet test

LAST_TAG="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
if [ -z "$LAST_TAG" ]; then
  VERSION="0.1.0"
else
  RANGE="${LAST_TAG}..HEAD"
  [ "$(git rev-list --count "$RANGE")" -gt 0 ] || fail "no commits since $LAST_TAG"
  if [ -z "$BUMP" ]; then
    if git log --format='%s%n%b' "$RANGE" | grep -qE '^[a-z]+(\([^)]+\))?!:|^BREAKING CHANGE:'; then
      BUMP="major"
    elif git log --format='%s' "$RANGE" | grep -qE '^feat(\([^)]+\))?:'; then
      BUMP="minor"
    else
      BUMP="patch"
    fi
  fi
  IFS=. read -r MAJOR MINOR PATCH <<<"${LAST_TAG#v}"
  case "$BUMP" in
    major) VERSION="$((MAJOR + 1)).0.0" ;;
    minor) VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
    patch) VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  esac
fi
TAG="v${VERSION}"
echo "publish: ${LAST_TAG:-none} -> ${TAG} (${BUMP:-first release})"

git tag -a "$TAG" -m "Skylight ${VERSION}"
git push origin main "$TAG"

scripts/release.sh --no-install
ZIP="dist/Skylight-${TAG}.zip"
[ -f "$ZIP" ] || fail "expected $ZIP after the build"

gh release create "$TAG" "$ZIP" --title "Skylight ${VERSION}" --generate-notes

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

TAP_DIR="$(mktemp -d)"
trap 'rm -rf "$TAP_DIR"' EXIT
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --depth 1
mkdir -p "$TAP_DIR/Casks"
cat >"$TAP_DIR/Casks/skylight.rb" <<EOF
cask "skylight" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/awmwong/skylight/releases/download/v#{version}/Skylight-v#{version}.zip"
  name "Skylight"
  desc "Menu bar app that mirrors a screen region into a shareable window"
  homepage "https://github.com/awmwong/skylight"

  depends_on macos: :sonoma

  app "Skylight.app"

  caveats <<~EOS
    Skylight is not notarized, so macOS blocks the first launch. Clear the
    quarantine attribute:

      xattr -d -r com.apple.quarantine /Applications/Skylight.app

    Or open the app once, let macOS refuse, then approve Skylight in
    System Settings > Privacy & Security.
  EOS
end
EOF
git -C "$TAP_DIR" add Casks/skylight.rb
git -C "$TAP_DIR" commit -m "skylight ${VERSION}"
git -C "$TAP_DIR" push

echo "published: ${TAG}"
echo "install: brew install --cask awmwong/tap/skylight"
