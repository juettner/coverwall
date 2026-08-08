# Releasing Coverwall

Maintainer notes — not user-facing.

One-time setup: `xcrun notarytool store-credentials coverwall-notary` with an
App Store Connect API key. Then, for each release:

```sh
export CW_TEAM_ID=XXXXXXXXXX
export CW_SIGN_IDENTITY="Developer ID Application: Chad Juettner (XXXXXXXXXX)"
export CW_NOTARY_PROFILE=coverwall-notary
./scripts/publish.sh 1.0.0
```

`publish.sh` builds a signed, notarized DMG (via `scripts/release.sh`),
tags the repo, creates the GitHub release with the DMG attached, and bumps
the [Homebrew tap](https://github.com/juettner/homebrew-coverwall) cask with
the new version and sha256.

Per-release checklist:

- Refresh the starter-set chart snapshot in
  `CoverwallShared/Sources/CoverwallShared/StarterSet.swift` (global daily
  top tracks; dedupe by album).
- `cd CoverwallShared && swift test` — all green.
- `./scripts/publish.sh <version>`.
- Smoke-test `brew install juettner/coverwall/coverwall` on a clean machine
  if possible.

Local dev with your own Spotify credentials: create an app at
developer.spotify.com/dashboard with redirect URI `coverwall://callback` and
put its Client ID in `CoverwallShared/Sources/CoverwallShared/SpotifyConfig.swift`.
