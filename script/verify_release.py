#!/usr/bin/env python3
"""Verify a packaged app without signing in or contacting a usage provider."""
import argparse
import base64
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import zipfile
from pathlib import PurePosixPath

ROOT = Path(__file__).resolve().parent.parent

PRIVATE_PATH = re.compile(rb'/Users/[^/\x00\r\n]{1,80}/')
CREDENTIAL_MATERIAL = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----|\bsk-(?:ant-)?[A-Za-z0-9_-]{20,}|\b(?:AKIA|ASIA)[A-Z0-9]{16}\b|\bgh[pousr]_[A-Za-z0-9]{25,}')
PRIVATE_FILE = re.compile(r'(?i)(?:^|/)(?:config\.local\.json|\.env(?:\.[^/]*)?|\.ssh|\.aws|\.codex|\.claude|keychains?|cookies|login data|snapshot\.json|preferences\.json|auth\.json|overview\.json|native-overview\.json|history\.json|alerts\.json|connection-(?:health|readings)\.json)(?:/|$)|\.(?:p12|pfx|key|kdbx)$')


def reject_private_payload(name, data):
    """Fail with the file/category only; never echo a potential private value."""
    if PRIVATE_FILE.search(name):
        raise ValueError(name + ': private file is not distributable')
    if PRIVATE_PATH.search(data):
        raise ValueError(name + ': developer home path in distributed payload')
    if CREDENTIAL_MATERIAL.search(data):
        raise ValueError(name + ': credential-shaped material in distributed payload')


def run(command, env=None):
    return subprocess.run(command, capture_output=True, text=True, check=True, timeout=45, env=env)


def validate_archive_paths(zipped):
    for entry in zipped.infolist():
        parts = PurePosixPath(entry.filename)
        if parts.is_absolute() or '..' in parts.parts or '\\' in entry.filename:
            raise ValueError('Unsafe archive path')
        if (entry.external_attr >> 16) & 0o170000 == 0o120000:
            target = zipped.read(entry).decode('utf-8')
            # Framework links are relative and must resolve within the app.
            resolved = os.path.normpath(str(parts.parent / target))
            if target.startswith('/') or not resolved.startswith('OVRCAST.app/'):
                raise ValueError('Unsafe archive symlink')


def verify(archive, notarized=False):
    version = json.loads((ROOT / 'app/version.json').read_text())
    with zipfile.ZipFile(archive) as zipped:
        validate_archive_paths(zipped)
        if zipped.testzip() is not None:
            raise ValueError('ZIP integrity failure')
    with tempfile.TemporaryDirectory() as directory:
        run(['/usr/bin/ditto', '-x', '-k', str(archive), directory])
        app = Path(directory) / 'OVRCAST.app'
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == 'com.weekthink.usageboard'
        assert info['CFBundleShortVersionString'] == version['version'] and info['CFBundleVersion'] == version['build']
        assert info['LSMinimumSystemVersion'] == '14.0'
        updates = json.loads((ROOT / 'app/updates.json').read_text())
        assert info['SUFeedURL'] == updates['feed'] and info['SUFeedURL'].startswith('https://')
        assert info['SUPublicEDKey'] == updates['publicKey'] and len(base64.b64decode(updates['publicKey'], validate=True)) == 32
        assert info['SURequireSignedFeed'] and info['SUVerifyUpdateBeforeExtraction']
        assert info['SUEnableSystemProfiling'] is False and info['SUEnableAutomaticChecks'] is False
        assert info['SUAutomaticallyUpdate'] is False
        assert any('usageboard' in row.get('CFBundleURLSchemes', []) for row in info['CFBundleURLTypes'])
        run(['codesign', '--verify', '--deep', '--strict', str(app)])
        for name in ['Contents/MacOS/UsageBoardMenuBar', 'Contents/Helpers/OVRCASTCollector']:
            executable = app / name
            assert {'arm64', 'x86_64'} <= set(run(['lipo', '-archs', str(executable)]).stdout.split())
            assert run(['xcrun', 'vtool', '-show-build', str(executable)]).stdout.count('minos 14.0') == 2
        for path in app.rglob('*'):
            if path.is_symlink() and not path.resolve().is_relative_to(app.resolve()):
                raise ValueError('Symlink escapes app bundle')
            if path.is_file(): reject_private_payload(path.relative_to(app).as_posix(), path.read_bytes())
        resources = app / 'Contents/Resources'
        assert (resources / 'LICENSES/Sparkle.txt').is_file()
        framework = app / 'Contents/Frameworks/Sparkle.framework'
        run(['codesign', '--verify', '--deep', '--strict', str(framework)])
        assert {'arm64', 'x86_64'} <= set(run(['lipo', '-archs', str(framework / 'Sparkle')]).stdout.split())
        assert '@rpath/Sparkle.framework/Versions/B/Sparkle' in run(['otool', '-L', str(app / 'Contents/MacOS/UsageBoardMenuBar')]).stdout
        assert (resources / 'UsageBoard.icns').read_bytes() == (ROOT / 'app/UsageBoard.icns').read_bytes()
        for name in ['codex', 'claude', 'antigravity']:
            assert (resources / ('assets/provider-logos/' + name + '.png')).is_file()
        for name in ['LICENSE', 'Sources/CQuickJS/LICENSE', 'Dependencies/Commander/LICENSE',
                     'Dependencies/SweetCookieKit/LICENSE', 'Dependencies/swift-log/LICENSE.txt', 'Dependencies/swift-log/NOTICE.txt']:
            assert (resources / 'CollectorLicenses' / name).is_file()
        helper = str(app / 'Contents/Helpers/OVRCASTCollector')
        smoke = subprocess.run([helper], env=dict(os.environ, CODEXBAR_RESOURCE_SMOKE='1'),
                               capture_output=True, text=True, timeout=45, check=True)
        assert 'CODEXBAR_RESOURCE_SMOKE_OK' in smoke.stdout
        for args in [['serve'], ['config', 'login'], ['codex-accounts', 'activate']]:
            blocked = subprocess.run([helper] + args, capture_output=True, text=True, timeout=10)
            assert blocked.returncode == 2
        if notarized:
            run(['xcrun', 'stapler', 'validate', str(app)])
            run(['spctl', '--assess', '--type', 'execute', str(app)])
    return {'version': version['version'], 'universal': True, 'signature': True,
            'packaged_resources': True, 'notarization_checked': notarized}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--notarized', action='store_true')
    arguments = parser.parse_args()
    print(json.dumps(verify(arguments.archive, arguments.notarized), indent=2))
