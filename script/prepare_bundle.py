#!/usr/bin/env python3
"""Embed the pinned updater with its symlinks intact and write public metadata."""
import json
from pathlib import Path
import plistlib
import subprocess
import sys


def prepare(app, root):
    version = json.loads((root / 'app/version.json').read_text())
    updates = json.loads((root / 'app/updates.json').read_text())
    framework = root / 'native/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework'
    if not framework.is_dir():
        raise ValueError('Pinned Sparkle framework missing; resolve/build the native package first')
    destination = app / 'Contents/Frameworks/Sparkle.framework'
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['/usr/bin/ditto', str(framework), str(destination)], check=True)
    info = {'CFBundleExecutable': 'UsageBoardMenuBar', 'CFBundleIdentifier': 'com.weekthink.usageboard',
            'CFBundleName': 'OVRCAST', 'CFBundleDisplayName': 'OVRCAST', 'CFBundlePackageType': 'APPL',
            'CFBundleShortVersionString': version['version'], 'CFBundleVersion': version['build'],
            'CFBundleIconFile': 'UsageBoard.icns', 'LSMinimumSystemVersion': '14.0',
            'NSPrincipalClass': 'NSApplication', 'LSUIElement': True,
            'CFBundleURLTypes': [{'CFBundleURLName': 'com.weekthink.usageboard', 'CFBundleURLSchemes': ['usageboard']}],
            'SUFeedURL': updates['feed'], 'SUPublicEDKey': updates['publicKey'],
            'SUEnableAutomaticChecks': False, 'SUAutomaticallyUpdate': False,
            'SUEnableSystemProfiling': False, 'SURequireSignedFeed': True,
            'SUVerifyUpdateBeforeExtraction': True}
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))


if __name__ == '__main__':
    prepare(Path(sys.argv[1]), Path(sys.argv[2]))
