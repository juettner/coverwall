#!/bin/bash
# Publish a Coverwall release: build/sign/notarize the DMG, create the GitHub
# release, and bump the Homebrew cask in the juettner/homebrew-coverwall tap.
#
# Usage: scripts/publish.sh 1.0.0
#
# Requires the same env as release.sh (CW_TEAM_ID, CW_SIGN_IDENTITY,
# CW_NOTARY_PROFILE), an authenticated `gh` on the juettner account, and a
# checkout of the tap (default ~/projects/homebrew-coverwall, override with
# CW_TAP_DIR).
set -euo pipefail

VERSION="${1:?Usage: publish.sh <version>  (e.g. 1.0.0)}"
TAP_DIR="${CW_TAP_DIR:-$HOME/projects/homebrew-coverwall}"
CASK="$TAP_DIR/Casks/coverwall.rb"

cd "$(dirname "$0")/.."

[[ -z "$(git status --porcelain)" ]] || { echo "error: working tree not clean" >&2; exit 1; }
[[ -f "$CASK" ]] || { echo "error: cask not found at $CASK (set CW_TAP_DIR)" >&2; exit 1; }
git rev-parse "v$VERSION" >/dev/null 2>&1 && { echo "error: tag v$VERSION already exists" >&2; exit 1; }

./scripts/release.sh

git tag -a "v$VERSION" -m "Coverwall $VERSION"
git push origin main "v$VERSION"
gh release create "v$VERSION" dist/Coverwall.dmg --title "Coverwall $VERSION" --generate-notes

SHA=$(shasum -a 256 dist/Coverwall.dmg | awk '{print $1}')
sed -i '' \
  -e "s/^  version .*/  version \"$VERSION\"/" \
  -e "s/^  sha256 .*/  sha256 \"$SHA\"/" \
  "$CASK"

git -C "$TAP_DIR" add Casks/coverwall.rb
git -C "$TAP_DIR" commit -m "coverwall $VERSION"
git -C "$TAP_DIR" push

echo
echo "Published Coverwall $VERSION."
echo "Install with: brew install juettner/coverwall/coverwall"
