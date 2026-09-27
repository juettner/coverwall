#!/bin/bash
# Builds the Windows artifacts (from macOS or Windows) into windows/dist:
# Coverwall.scr (the screensaver) and CoverwallTray.exe (the observer),
# self-contained win-x64 so testers need no .NET install.
set -euo pipefail
cd "$(dirname "$0")"

DOTNET="${DOTNET:-$HOME/.dotnet/dotnet}"
command -v "$DOTNET" >/dev/null || DOTNET=dotnet

rm -rf dist publish
mkdir -p dist
cp TESTING.md dist/README.txt

# win-x64 for ordinary PCs; win-arm64 for Windows-on-ARM (including VMs on
# Apple Silicon, where ARM runs natively and x64 only emulates).
for RID in win-x64 win-arm64; do
  "$DOTNET" publish CoverwallSaver -c Release -r "$RID" --self-contained \
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
    -o "publish/$RID/saver"
  "$DOTNET" publish CoverwallTray -c Release -r "$RID" --self-contained \
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
    -o "publish/$RID/tray"

  STAGE="dist/$RID"
  mkdir -p "$STAGE"
  cp "publish/$RID/saver/Coverwall.exe" "$STAGE/Coverwall.scr"
  cp "publish/$RID/tray/CoverwallTray.exe" "$STAGE/"
  cp TESTING.md "$STAGE/README.txt"

  SUFFIX=$([ "$RID" = "win-x64" ] && echo "" || echo "-arm64")
  (cd "$STAGE" && zip -q -r "../CoverwallWindows$SUFFIX.zip" \
    Coverwall.scr CoverwallTray.exe README.txt)
done
echo "Built: windows/dist/CoverwallWindows.zip and CoverwallWindows-arm64.zip"
