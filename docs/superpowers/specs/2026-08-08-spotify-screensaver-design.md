# Coverwall — Spotify Album Art Screensaver — Design

**Date:** 2026-08-08
**Status:** Approved

## Summary

**Coverwall** is a real macOS screensaver that displays a grid mosaic of album
art from the user's Spotify listening. Distributed publicly as a signed,
notarized download. Two runtime pieces: a menu-bar helper app that owns Spotify
auth and art caching, and a `.saver` bundle that only renders from the local
cache. The name deliberately avoids "Spotify" to comply with Spotify's
developer branding guidelines.

## Goals

- Appears in System Settings › Screen Saver like any native screensaver.
- Album art reflects the user's actual Spotify activity; source is configurable.
- Installable by anyone: no Gatekeeper warnings, no manual `.saver` copying.
- The screensaver never shows a black screen, an error dialog, or a login prompt.

## Non-goals

- Windows/Linux support.
- Live "now playing" mode, drifting collage, or other display modes. Grid mosaic
  is the only mode in v1 and there is no display-mode setting; adding one later
  is a straightforward extension.
- Playback control or any Spotify write scopes.

## Architecture

One Xcode project, three targets:

### 1. `Coverwall.app` (menu-bar helper — the distributed artifact)

- On first launch: installs/updates `Coverwall.saver` into
  `~/Library/Screen Savers`, then runs Spotify login onboarding.
- OAuth 2.0 Authorization Code + PKCE via `ASWebAuthenticationSession`, loopback
  redirect. No client secret embedded (PKCE requires none). Scopes:
  `user-read-recently-played`, `user-top-read`, `user-library-read`.
- Tokens stored in Keychain. Access token refreshed silently.
- Fetch schedule: recently played every 15 min; top tracks / liked songs hourly.
  Also fetches on wake-from-sleep and via a manual "Refresh now" menu item.
- Downloads 640×640 cover art, dedupes by album ID, writes images plus
  `manifest.json` (atomic replace) to the App Group container.
- Cache cap ~200 covers; least-recently-referenced pruned.
- Login item via `SMAppService` so art stays fresh without the user thinking
  about it.

### 2. `Coverwall.saver` (ScreenSaverView, AppKit + Core Animation)

- Renders covers edge to edge in a grid sized from the tile-density setting.
- Every flip interval, one random tile crossfades to a different cached album.
- Reads only from the App Group cache. Zero network, zero auth, no Keychain.
- Reloads the manifest when its timestamp changes (checked ~1/min).
- `configureSheet` (System Settings options): display-only settings + an
  "Open Coverwall settings" button that launches the helper.
- Multi-display: each screen gets its own independently animating grid
  (ScreenSaverEngine instantiates one view per screen; no extra work beyond
  not sharing mutable state between instances).

### 3. `CoverwallShared` (Swift package)

- Cache manifest model, App Group paths, settings keys/defaults.
- Helper and saver share data only through: App Group files (images, manifest)
  and App Group `UserDefaults` (settings). Both targets signed with the same
  Team ID and app-group entitlement.

## Settings (helper app UI; stored in shared UserDefaults)

| Setting | Options | Default |
|---|---|---|
| Art source | Recently played / Top tracks / Liked Songs | Recently played |
| Top-tracks range | 4 weeks / 6 months / all time | 6 months (shown only when source = Top tracks) |
| Tile density | Small / Medium / Large | Medium |
| Flip interval | 2–15 s slider | 4 s |
| Track label overlay | On / Off | Off |

## Data flow

1. Helper fetches configured source → dedupes albums → downloads missing art.
2. Helper writes images, then atomically replaces `manifest.json`
   (album id, image filename, title, artist, fetch timestamp, source).
3. Saver loads manifest at `startAnimation`, fills grid, animates flips.
4. Saver polls manifest mtime once a minute; on change, folds new art into the
   flip rotation (no jarring full-grid reload).
5. Fewer albums than grid cells → covers repeat at different positions.

## Error handling

| Condition | Behavior |
|---|---|
| Helper never run / not logged in | Saver renders muted gradient placeholder mosaic + one line: "Open Coverwall to connect your Spotify account." |
| Refresh token revoked/invalid | Menu-bar icon shows attention badge; helper shows re-login prompt on click; saver continues on cached art. |
| Offline / 5xx / rate limited | Exponential backoff in helper; saver unaffected (stale cache is fine). |
| Sparse history | Grid fills by repeating covers; no minimum. |
| Corrupt manifest/image | Helper rewrites on next cycle; saver skips unreadable entries, falls back to placeholder only if zero valid images. |

The saver must never crash, block, or show system UI — worst case is the
placeholder mosaic.

## Distribution

- Developer ID Application signing + notarization + stapling for the app;
  the embedded `.saver` signed with the same identity.
- Ship a DMG containing only the helper app (it installs the saver itself).
- Build script (also CI-runnable): archive → sign → notarize → staple → DMG.
- Spotify: register app, request extended-quota review for public users.
  Until approved, dev mode allows 25 allowlisted users (friends/testers).

## Testing

- **Unit** (helper + shared): manifest round-trip, atomic-write behavior, cache
  pruning, API client against canned JSON fixtures, PKCE verifier/challenge.
- **Preview harness**: dev-only app target hosting `ScreenSaverView` in a
  resizable window for fast visual iteration without installing the saver.
- **Manual matrix pre-release**: fresh machine (no login) placeholder, login
  flow, each art source, settings changes propagating, multi-display, System
  Settings thumbnail/preview, wake-from-sleep refresh.

## Open items (not blockers for implementation)

- Spotify extended-quota review must be submitted early — approval latency is
  weeks and gates public distribution.
- Product name is **Coverwall** (decided 2026-08-08) — chosen partly because
  Spotify's developer design guidelines forbid names implying Spotify made the
  app. Marketing copy must still follow those guidelines ("Coverwall for
  Spotify"-style attribution only where permitted).
