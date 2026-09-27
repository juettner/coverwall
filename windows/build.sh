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

"$DOTNET" publish CoverwallSaver -c Release -r win-x64 --self-contained \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
  -o publish/saver
"$DOTNET" publish CoverwallTray -c Release -r win-x64 --self-contained \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
  -o publish/tray

cp publish/saver/Coverwall.exe dist/Coverwall.scr
cp publish/tray/CoverwallTray.exe dist/
cp TESTING.md dist/README.txt 2>/dev/null || true

(cd dist && zip -q -r CoverwallWindows.zip Coverwall.scr CoverwallTray.exe README.txt)
echo "Built: windows/dist/CoverwallWindows.zip"
