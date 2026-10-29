#!/bin/zsh
# Package the OVRCAST raster icon at every native macOS icon size.
# Usage: app/build_icon.sh (from anywhere)
set -euo pipefail
HERE=${0:A:h}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/UsageBoard.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$HERE/icon_1024.png" --out "$WORK/UsageBoard.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$HERE/icon_1024.png" --out "$WORK/UsageBoard.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/UsageBoard.iconset" -o "$HERE/UsageBoard.icns"
print "built $HERE/UsageBoard.icns"
