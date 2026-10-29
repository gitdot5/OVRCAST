#!/usr/bin/env python3
"""Refresh the fork allowlist after intentional reviewed vendor edits."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parent.parent / 'vendor/OVRCASTCollector'
rows = []
for path in sorted(root.rglob('*')):
    relative = path.relative_to(root)
    if any(x in relative.parts for x in ('.build', '.swiftpm', '.git')) or path.name in ('FILE_MANIFEST.sha256', '.DS_Store', 'Package.resolved'):
        continue
    if path.is_symlink():
        raise SystemExit('Vendor symlinks are not allowed')
    if path.is_file():
        rows.append(hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + relative.as_posix() + '\n')
(root / 'FILE_MANIFEST.sha256').write_text(''.join(rows))
print('Pinned', len(rows), 'vendor source files')
