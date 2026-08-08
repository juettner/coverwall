#!/bin/bash
set -euo pipefail

: "${CW_TEAM_ID:?Set CW_TEAM_ID to your Apple Developer Team ID}"
: "${CW_SIGN_IDENTITY:?Set CW_SIGN_IDENTITY to your Developer ID Application identity}"
: "${CW_NOTARY_PROFILE:?Set CW_NOTARY_PROFILE to your notarytool keychain profile name}"

cd "$(dirname "$0")/.."

if grep -rq "MISSING_CLIENT_ID" CoverwallShared/Sources; then
  echo "error: SpotifyConfig.clientID is still MISSING_CLIENT_ID" >&2; exit 1
fi
BUILD_NUMBER=$(git rev-list --count HEAD)

rm -rf dist build/Release-export
mkdir -p dist

xcodegen
xcodebuild -project Coverwall.xcodeproj -scheme Coverwall -configuration Release \
  DEVELOPMENT_TEAM="$CW_TEAM_ID" \
  CODE_SIGN_IDENTITY="$CW_SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  CONFIGURATION_BUILD_DIR="$PWD/build/Release-export" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build

APP="build/Release-export/Coverwall.app"
codesign --verify --deep --strict "$APP"

hdiutil create -volname Coverwall -srcfolder "$APP" -ov -format UDZO dist/Coverwall.dmg
xcrun notarytool submit dist/Coverwall.dmg --keychain-profile "$CW_NOTARY_PROFILE" --wait
xcrun stapler staple dist/Coverwall.dmg

echo "Done: dist/Coverwall.dmg"
