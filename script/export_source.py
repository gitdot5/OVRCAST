#!/usr/bin/env python3
"""Create a clean source archive without local state, artwork or Git history."""
import argparse
import hashlib
import re
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent
FILES = (
    '.gitignore', 'LICENSE', 'SECURITY.md', 'THIRD_PARTY_NOTICES.md', 'README.md', 'config.json',
    'board.py', 'capacity.py', 'collect.py', 'dashboard.py', 'dashboard.css',
    'dashboard.js', 'gather.py', 'install_agent.py', 'native_snapshot.py',
    'native/Package.swift', 'app/install_app.sh', 'app/build_icon.sh',
    'app/icon.svg', 'app/icon_1024.png', 'app/UsageBoard.icns',
    'script/build_and_run.sh', 'script/package_release.sh', 'script/export_source.py', 'assets/README.md', 'docs/preview.png',
)
TREES = {
    'tests': {'.py', '.json', '.jsonl'},
    'native/Sources': {'.swift'},
    'native/Tests': {'.swift'},
    'docs': {'.md', '.txt'},
    'LICENSES': {'.txt'},
}
EMAIL = re.compile(r'[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})')
EXAMPLE_DOMAINS = {'example.com', 'example.net', 'example.org', 'example.invalid'}
PRIVATE_PATH = re.compile(r'/Users/[A-Za-z0-9_.-]+/')
PRIVATE_HOST = re.compile(r'\b[A-Za-z0-9.-]+\.ts\.net\b|\b(?:10|192\.168)\.(?:\d{1,3}\.){1,2}\d{1,3}\b')
CREDENTIAL = re.compile(r'\bsk-(?:ant-)?[A-Za-z0-9_-]{16,}|\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|Bearer\s+[A-Za-z0-9._-]{20,}')
# These exact fake inputs exercise the credential detector in tests. They are
# intentionally public and are never used by a provider.
DUMMY_CREDENTIALS = (
    'sk-ant-oat01-' + 'A' * 20,
    'sk-ant-oat01-' + 'A' * 16,
    'eyJhbGciOiJSUzI1NiJ9.' + 'eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc',
    'Bearer ' + 'abcdefghijklmnopqrstuvwxyz0123',
)


def validate_text(name, text):
    """Fail closed with a filename and category, never echo the sensitive value."""
    if any(m.group(1).lower() not in EXAMPLE_DOMAINS for m in EMAIL.finditer(text)):
        raise ValueError(name + ': non-example account identity')
    if PRIVATE_PATH.search(text) or PRIVATE_HOST.search(text):
        raise ValueError(name + ': private machine path or hostname')
    if name == 'tests/test_collect.py':
        for dummy in DUMMY_CREDENTIALS:
            text = text.replace(dummy, 'PUBLIC_TEST_PLACEHOLDER')
    if CREDENTIAL.search(text):
        raise ValueError(name + ': credential-shaped content')


def source_files(root):
    names = set(FILES)
    for folder, suffixes in TREES.items():
        for path in (root / folder).rglob('*'):
            if path.suffix in suffixes and '__pycache__' not in path.parts:
                names.add(path.relative_to(root).as_posix())
    result = {}
    for name in sorted(names):
        path = root / name
        if any(parent.is_symlink() for parent in (path, *path.parents) if parent != root.parent):
            raise ValueError(name + ': symlinks are excluded')
        data = path.read_bytes()
        if path.suffix not in {'.png', '.icns'}:
            validate_text(name, data.decode('utf-8'))
        result[name] = data
    return result


def export(root, output):
    files = source_files(root)
    # Fixed timestamps and modes keep repeated exports of the same files stable.
    manifest = ''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n'
                       for name, data in files.items())
    files['SHA256SUMS'] = manifest.encode()
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + '.tmp')
    try:
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for name, data in files.items():
                entry = zipfile.ZipInfo('usage_board/' + name, date_time=(2026, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                mode = 0o755 if name.endswith('.sh') else 0o644
                entry.external_attr = (0o100000 | mode) << 16
                archive.writestr(entry, data)
        temporary.replace(output)
    finally:
        if temporary.exists():
            temporary.unlink()
    return len(files)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist' / 'OVRCAST-source.zip')
    args = parser.parse_args()
    try:
        count = export(ROOT, args.output.resolve())
    except (ValueError, OSError) as error:
        parser.exit(1, 'Source export refused: ' + str(error) + '\n')
    print('Exported %d files to %s' % (count, args.output.resolve()))
