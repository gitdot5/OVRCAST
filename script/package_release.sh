#!/bin/bash
# Build a clean universal preview DMG. Optional Developer ID signing and notarization.
set -euo pipefail
MODE="${1:-dmg}"
case "$MODE" in dmg|--zip-only) ;; *) echo 'Usage: package_release.sh [--zip-only]' >&2; exit 2;; esac
if [[ -n "${NOTARY_PROFILE:-}" && -z "${DEVELOPER_ID:-}" ]]; then echo 'Notarization requires DEVELOPER_ID.' >&2; exit 2; fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
/usr/bin/python3 "$ROOT_DIR/script/export_source.py"
/usr/bin/ditto -x -k "$ROOT_DIR/dist/OVRCAST-source.zip" "$WORK_DIR"
SOURCE_DIR="$WORK_DIR/usage_board"
swift build --package-path "$SOURCE_DIR/native" -c release --arch arm64 --arch x86_64 -j 2
BUILD_DIR="$(swift build --package-path "$SOURCE_DIR/native" -c release --arch arm64 --arch x86_64 --show-bin-path)"
STAGE_DIR="$WORK_DIR/disk"
APP_DIR="$STAGE_DIR/OVRCAST.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/UsageBoardMenuBar" "$APP_DIR/Contents/MacOS/UsageBoardMenuBar"
"$SOURCE_DIR/script/build_collector.sh" "$APP_DIR/Contents"
cp "$SOURCE_DIR/app/UsageBoard.icns" "$APP_DIR/Contents/Resources/"
ditto "$SOURCE_DIR/assets/provider-logos" "$APP_DIR/Contents/Resources/assets/provider-logos"
cp "$SOURCE_DIR/LICENSE" "$SOURCE_DIR/THIRD_PARTY_NOTICES.md" "$APP_DIR/Contents/Resources/"
ditto "$SOURCE_DIR/LICENSES" "$APP_DIR/Contents/Resources/LICENSES"
/usr/bin/python3 - "$APP_DIR/Contents/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as f:
 plistlib.dump({'CFBundleExecutable':'UsageBoardMenuBar','CFBundleIdentifier':'com.weekthink.usageboard',
 'CFBundleName':'OVRCAST','CFBundleDisplayName':'OVRCAST','CFBundlePackageType':'APPL',
 'CFBundleShortVersionString':'0.4.0','CFBundleVersion':'7','CFBundleIconFile':'UsageBoard.icns',
 'LSMinimumSystemVersion':'14.0','NSPrincipalClass':'NSApplication','LSUIElement':True,
 'CFBundleURLTypes':[{'CFBundleURLName':'com.weekthink.usageboard','CFBundleURLSchemes':['usageboard']}]},f)
PY
if [[ -n "${DEVELOPER_ID:-}" ]]; then
 codesign --force --options runtime --timestamp --identifier com.weekthink.ovrcast.collector --sign "$DEVELOPER_ID" "$APP_DIR/Contents/Helpers/OVRCASTCollector"
 codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP_DIR"
else
 codesign --force --sign - "$APP_DIR/Contents/Helpers/OVRCASTCollector"
 codesign --force --sign - "$APP_DIR"
fi
codesign --verify --deep --strict "$APP_DIR"
ZIP_OUTPUT="$ROOT_DIR/dist/OVRCAST-0.4.0-preview.app.zip"
/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP_OUTPUT"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
 xcrun notarytool submit "$ZIP_OUTPUT" --keychain-profile "$NOTARY_PROFILE" --wait
 xcrun stapler staple "$APP_DIR"
 xcrun stapler validate "$APP_DIR"
 spctl --assess --type execute "$APP_DIR"
 rm "$ZIP_OUTPUT"
 /usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP_OUTPUT"
fi
shasum -a 256 "$ZIP_OUTPUT" > "$ZIP_OUTPUT.sha256"
if [[ "$MODE" == "--zip-only" ]]; then
 echo "Packaged $ZIP_OUTPUT"
 if [[ -z "${NOTARY_PROFILE:-}" ]]; then echo 'Preview build: notarization has not been completed.'; fi
 exit 0
fi
ln -s /Applications "$STAGE_DIR/Applications"
cp "$SOURCE_DIR/docs/QUICK_START.txt" "$STAGE_DIR/Read me first.txt"
OUTPUT="$ROOT_DIR/dist/OVRCAST-0.4.0-preview.dmg"
hdiutil create -volname 'OVRCAST' -srcfolder "$STAGE_DIR" -ov -format UDZO "$OUTPUT" >/dev/null
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
 if [[ -z "${DEVELOPER_ID:-}" ]]; then echo 'Notarization requires DEVELOPER_ID.' >&2; exit 2; fi
 xcrun notarytool submit "$OUTPUT" --keychain-profile "$NOTARY_PROFILE" --wait
 xcrun stapler staple "$OUTPUT"
 xcrun stapler validate "$OUTPUT"
fi
shasum -a 256 "$OUTPUT" > "$OUTPUT.sha256"
echo "Packaged $OUTPUT"
if [[ -z "${NOTARY_PROFILE:-}" ]]; then echo 'Preview build: notarization has not been completed.'; fi
