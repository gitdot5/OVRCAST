# Third-party notices

## CodexBar

OVRCAST includes an OVRCAST-maintained source fork of CodexBar v0.81.0,
revision `ee890b5f392e70d6e20162d3e95cf9f1be265b60`, compiled as
`Contents/Helpers/OVRCASTCollector`. A separate CodexBar installation is not needed.
The provider switcher and allowance presentation also take design inspiration
from CodexBar. Its public Codex identification image is credited in `assets/README.md`.

CodexBar: https://github.com/steipete/CodexBar

Copyright (c) 2026 Peter Steinberger. Licensed under the MIT License.
The complete v0.81.0 license is retained in `LICENSES/CodexBar-MIT.txt` and
`vendor/OVRCASTCollector/LICENSE`. See `vendor/OVRCASTCollector/FORK.md`,
`UPSTREAM.json` and `DEPENDENCIES.json` for source provenance and fork changes.

The collector retains these locally pinned source dependencies and licenses:

- Commander: MIT, `vendor/OVRCASTCollector/Dependencies/Commander/LICENSE`.
- SweetCookieKit: MIT, `vendor/OVRCASTCollector/Dependencies/SweetCookieKit/LICENSE`.
- swift-log: Apache 2.0, including its runtime library exception and NOTICE,
  under `vendor/OVRCASTCollector/Dependencies/swift-log/`.
- QuickJS: MIT, `vendor/OVRCASTCollector/Sources/CQuickJS/LICENSE`.
- CodexBar's retained resource acknowledgements are under its core resources.

The app bundles these notices in `Contents/Resources/CollectorLicenses`.
macOS supplies CryptoKit, JavaScriptCore, SQLite and other system libraries.
The fork does not include CodexBar’s app, updater, widget or remote package fetches.

## Artwork and names

OVRCAST's original segmented capacity-ring app icon (`app/icon.svg` and rendered variants)
is included under the project's MIT license.

Provider names identify the services being monitored. Third-party names, logos,
and Apple hardware images are not relicensed by OVRCAST's MIT license.
The private development checkout may contain images extracted from locally
installed apps and macOS. `script/export_source.py` excludes those private images. The public app bundles
three provider identification images from the sources in `assets/README.md`;
device icons use macOS system symbols. No endorsement by
OpenAI, Anthropic, Google, Apple or CodexBar's authors is implied.

Apple frameworks and system symbols are supplied by macOS, not redistributed
as source assets in this package.
