#!/bin/bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OVRCAST"
PROCESS_NAME="UsageBoardMenuBar"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

case "$MODE" in run|--install|--verify|--build-only|--preview-day|--preview-night) ;; *) echo "Usage: $0 [--install|--verify|--build-only|--preview-day|--preview-night]" >&2; exit 2;; esac
pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
swift build --package-path "$ROOT_DIR/native" -j 2
BUILD_DIR="$(swift build --package-path "$ROOT_DIR/native" --show-bin-path)"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BUILD_DIR/$PROCESS_NAME" "$CONTENTS/MacOS/$PROCESS_NAME"
chmod +x "$CONTENTS/MacOS/$PROCESS_NAME"
cp "$ROOT_DIR/app/UsageBoard.icns" "$CONTENTS/Resources/UsageBoard.icns"
ditto "$ROOT_DIR/assets" "$CONTENTS/Resources/assets"
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$CONTENTS/Resources/"
ditto "$ROOT_DIR/LICENSES" "$CONTENTS/Resources/LICENSES"
/usr/bin/python3 - "$CONTENTS/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'wb') as f:
 plistlib.dump({'CFBundleExecutable':'UsageBoardMenuBar','CFBundleIdentifier':'com.weekthink.usageboard',
 'CFBundleName':'OVRCAST','CFBundleDisplayName':'OVRCAST','CFBundlePackageType':'APPL',
 'CFBundleShortVersionString':'0.3.3','CFBundleVersion':'6','CFBundleIconFile':'UsageBoard.icns',
 'LSMinimumSystemVersion':'14.0','NSPrincipalClass':'NSApplication','LSUIElement':True,
 'CFBundleURLTypes':[{'CFBundleURLName':'com.weekthink.usageboard','CFBundleURLSchemes':['usageboard']}]},f)
PY
codesign --force --deep -s - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
/usr/bin/python3 -I "$ROOT_DIR/gather.py" --quiet
if [[ "$MODE" == "--build-only" ]]; then exit 0; fi
if [[ "$MODE" == "--install" ]]; then
 # Keep the existing bundle identifier and data paths so renamed installs retain settings.
 if [[ -d "/Applications/Usage Board.app" ]]; then
  LEGACY_BACKUP="$ROOT_DIR/backups/$(date +%Y%m%d-%H%M%S)-rename"
  mkdir -p "$LEGACY_BACKUP"
  mv "/Applications/Usage Board.app" "$LEGACY_BACKUP/Usage Board.app"
 fi
 if [[ -d "/Applications/$APP_NAME.app" ]]; then
  BACKUP_DIR="$ROOT_DIR/backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  mv "/Applications/$APP_NAME.app" "$BACKUP_DIR/$APP_NAME.app"
 fi
 ditto "$APP_BUNDLE" "/Applications/$APP_NAME.app"
 APP_BUNDLE="/Applications/$APP_NAME.app"
 codesign --verify --deep --strict "$APP_BUNDLE"
 /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE"
fi
if [[ "$MODE" == "--preview-day" || "$MODE" == "--preview-night" ]]; then
 APPEARANCE="${MODE#--preview-}"
 mkdir -p "$ROOT_DIR/../outputs/usage-board-preview"
 /usr/bin/open -n "$APP_BUNDLE" --args --demo --snapshot "$ROOT_DIR/../outputs/usage-board-preview/menu-$APPEARANCE.png" "--$APPEARANCE" --diagnostics /tmp/usage-board-native-diagnostics.json --exit-after-snapshot
else
 /usr/bin/open -n "$APP_BUNDLE" --args --show --diagnostics /tmp/usage-board-native-diagnostics.json
fi
if [[ "$MODE" == "--verify" ]]; then
 sleep 1
 pgrep -x "$PROCESS_NAME" >/dev/null
fi
