#!/bin/bash
# Keep the private Ed25519 key in the macOS Keychain. Only public signatures leave it.
set -euo pipefail
if [[ $# -ne 2 ]]; then echo 'Usage: generate_update_feed.sh SPARKLE_BIN ARCHIVE_DIRECTORY' >&2; exit 2; fi
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT_DIR/app/version.json")"
"$1/generate_appcast" --account com.weekthink.ovrcast.updates --maximum-deltas 0 --embed-release-notes \
    --download-url-prefix "https://github.com/gitdot5/OVRCAST/releases/download/v$VERSION/" "$2"
