#!/bin/bash
# Native menu bar app; the prior AppleScript launcher is retained as source history.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT_DIR/script/build_and_run.sh" --install
