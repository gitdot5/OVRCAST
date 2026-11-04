#!/usr/bin/env python3
"""Sign nested updater code from the inside out, retaining its entitlements."""
import os
from pathlib import Path
import subprocess
import sys


def sign(app, identity):
    framework = app / 'Contents/Frameworks/Sparkle.framework'
    inner = framework / 'Versions/B'
    paths = [inner / 'XPCServices/Downloader.xpc', inner / 'XPCServices/Installer.xpc',
             inner / 'Updater.app', inner / 'Autoupdate', framework,
             app / 'Contents/Helpers/OVRCASTCollector', app]
    for path in paths:
        args = ['codesign', '--force', '--sign', identity]
        if identity != '-':
            args += ['--options', 'runtime', '--timestamp']
        if path.suffix == '.xpc':
            args += ['--preserve-metadata=entitlements']
        if path.name == 'OVRCASTCollector':
            args += ['--identifier', 'com.weekthink.ovrcast.collector']
        subprocess.run(args + [str(path)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)


if __name__ == '__main__':
    sign(Path(sys.argv[1]), os.environ.get('DEVELOPER_ID', '-'))
