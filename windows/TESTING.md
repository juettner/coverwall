# Coverwall for Windows — tester guide

Coverwall fills your screen with album art from what you play in Spotify.
It watches the Windows "now playing" system (the same thing the volume
overlay shows) — no Spotify login, no account access, nothing leaves your
PC.

## Install (2 minutes)

1. Unzip. You have two files: `CoverwallTray.exe` and `Coverwall.scr`.
2. Move both somewhere permanent (e.g. `C:\Users\<you>\Coverwall\`).
3. Double-click **CoverwallTray.exe**. Windows SmartScreen will warn that
   it's unrecognized (it's unsigned) — click *More info → Run anyway*.
   A Coverwall icon appears in the system tray.
4. Right-click **Coverwall.scr** → **Install**. Windows opens Screen Saver
   Settings with Coverwall selected — set your wait time and OK.
5. Optional but recommended: press Win+R, run `shell:startup`, and put a
   shortcut to `CoverwallTray.exe` there so it starts with Windows.

## Use

Play music in the Spotify desktop app while the tray icon is running.
Each track's cover is captured locally. The screensaver starts as a
colored placeholder grid and turns into your actual listening as plays
accumulate (an album appears as soon as it's been played once).

## What to report back

- Did tracks get picked up? (Check `%LOCALAPPDATA%\Coverwall\images` —
  cover art .jpg files should appear as you listen.)
- Does the screensaver show the art, flip tiles smoothly, and exit
  immediately on mouse/keyboard?
- Multi-monitor: does the wall cover all screens sensibly?
- Anything that crashed, hung, or looked wrong.
