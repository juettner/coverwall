# Coverwall

A macOS screensaver that fills your screen with a grid mosaic of album art
from your Spotify listening. A menu-bar helper app handles Spotify login and
keeps the art fresh; the screensaver itself is fully offline.

## Development

- Core logic + tests: `cd CoverwallShared && swift test`
- App/saver targets: `xcodegen && open Coverwall.xcodeproj`

See `docs/superpowers/specs/` for the design and `docs/superpowers/plans/`
for the implementation plan.

## Release

One-time setup: `xcrun notarytool store-credentials coverwall-notary` with an
App Store Connect API key, then:

    export CW_TEAM_ID=XXXXXXXXXX
    export CW_SIGN_IDENTITY="Developer ID Application: Chad Juettner (XXXXXXXXXX)"
    export CW_NOTARY_PROFILE=coverwall-notary
    ./scripts/release.sh

Output: `dist/Coverwall.dmg` (signed, notarized, stapled).

Distribution checklist: Spotify extended-quota review approved (users beyond
the 25-user dev allowlist), DMG smoke-tested on a clean machine.
