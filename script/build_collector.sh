#!/bin/bash
# Build the pinned local collector fork and place it inside an app's Contents directory.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTENTS="${1:?Usage: build_collector.sh /path/to/App.app/Contents}"
PACKAGE="$ROOT_DIR/vendor/OVRCASTCollector"
swift build --package-path "$PACKAGE" --product OVRCASTCollector -c release --arch arm64 --arch x86_64 -j 2
COLLECTOR_BUILD="$(swift build --package-path "$PACKAGE" -c release --arch arm64 --arch x86_64 --show-bin-path)"
mkdir -p "$CONTENTS/Helpers" "$CONTENTS/Resources"
cp "$COLLECTOR_BUILD/OVRCASTCollector" "$CONTENTS/Helpers/OVRCASTCollector"
chmod 755 "$CONTENTS/Helpers/OVRCASTCollector"
ditto "$COLLECTOR_BUILD/CodexBar_CodexBarCore.bundle" "$CONTENTS/Resources/CodexBar_CodexBarCore.bundle"
/usr/bin/python3 - "$PACKAGE" "$CONTENTS/Resources/CollectorLicenses" <<'PY'
from pathlib import Path
import sys,shutil
source,destination=map(Path,sys.argv[1:])
for path in source.rglob('*'):
    if not path.is_file() or any(x in path.relative_to(source).parts for x in ['.build','.swiftpm']): continue
    if path.name.lower().startswith(('license','notice','copying')) or path.name in ['FORK.md','UPSTREAM.json','DEPENDENCIES.json','Acknowledgements.json']:
        target=destination/path.relative_to(source);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
PY
