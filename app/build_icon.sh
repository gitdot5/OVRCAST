#!/bin/zsh
# Renders app/icon.svg (transparent corners) with headless Chrome and builds UsageBoard.icns.
# Usage: app/build_icon.sh   (from anywhere)
set -euo pipefail
HERE=${0:A:h}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

print -r -- "<!doctype html><html><head><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>$(<"$HERE/icon.svg")</body></html>" > "$WORK/icon.html"
"$CHROME" --headless --disable-gpu --hide-scrollbars --user-data-dir="$WORK/profile" \
  --default-background-color=00000000 --window-size=1024,1024 \
  --screenshot="$HERE/icon_1024.png" "file://$WORK/icon.html" >/dev/null 2>&1

mkdir -p "$WORK/UsageBoard.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$HERE/icon_1024.png" --out "$WORK/UsageBoard.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$HERE/icon_1024.png" --out "$WORK/UsageBoard.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/UsageBoard.iconset" -o "$HERE/UsageBoard.icns"
print "built $HERE/UsageBoard.icns"
