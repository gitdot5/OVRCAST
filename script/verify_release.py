#!/usr/bin/env python3
"""Verify a packaged app without signing in or contacting a usage provider."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def run(command, env=None):
    return subprocess.run(command, capture_output=True, text=True, check=True, timeout=45, env=env)


def verify(archive, notarized=False):
    version = json.loads((ROOT / 'app/version.json').read_text())
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None:
            raise ValueError('ZIP integrity failure')
    with tempfile.TemporaryDirectory() as directory:
        run(['/usr/bin/ditto', '-x', '-k', str(archive), directory])
        app = Path(directory) / 'OVRCAST.app'
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == 'com.weekthink.usageboard'
        assert info['CFBundleShortVersionString'] == version['version'] and info['CFBundleVersion'] == version['build']
        assert info['LSMinimumSystemVersion'] == '14.0'
        assert any('usageboard' in row.get('CFBundleURLSchemes', []) for row in info['CFBundleURLTypes'])
        run(['codesign', '--verify', '--deep', '--strict', str(app)])
        for name in ['Contents/MacOS/UsageBoardMenuBar', 'Contents/Helpers/OVRCASTCollector']:
            executable = app / name
            assert {'arm64', 'x86_64'} <= set(run(['lipo', '-archs', str(executable)]).stdout.split())
            assert run(['xcrun', 'vtool', '-show-build', str(executable)]).stdout.count('minos 14.0') == 2
        resources = app / 'Contents/Resources'
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
