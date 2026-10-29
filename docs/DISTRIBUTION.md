# Releasing OVRCAST

## Public download route

1. Create a new public GitHub repository from the contents of the clean
   `dist/OVRCAST-source.zip`. Start fresh history; do not push the private working
   checkout or upload the installed development app.
2. Use an Apple Developer ID Application certificate and either Xcode's signed-in
   account or a configured notarytool Keychain profile to notarize a clean release. Keep signing keys and
   authentication secrets out of the repository and release assets.
3. Validate the extracted app signature, ticket, Gatekeeper assessment and
   onboarding without access to development files or existing provider sessions.
   Test a separate Mac where available; disclose any unperformed platform tests
   in the release notes and mark the initial distribution as a public preview.
4. Create a draft GitHub Release. Attach the verified app ZIP or DMG, source ZIP,
   SHA-256 checksums and release notes. State macOS 14+, Apple Silicon/Intel,
   the CodexBar dependency, and any known limitations.
5. Enable GitHub private vulnerability reporting and protect the maintainer
   account with a passkey or strong two-factor authentication. Publish only
   after the downloaded assets match the locally verified checksums.
6. Link a simple OVRCAST download page to that exact release. Never link to the
   developer's Mac, SSH service, personal dashboard, snapshots or logs.

GitHub source publication and binary publication can happen separately. A source
release does not mean the binary has passed Apple notarization or independent
security review.

## Local preparation

```sh
swift test --package-path native -j 2
/usr/bin/python3 -m unittest discover -s tests
/usr/bin/python3 script/export_source.py
./script/package_release.sh --zip-only
```

Without explicit signing configuration this produces an ad-hoc-signed **preview**.
Do not present it as a notarized public release. The packager builds from the
source allowlist in a temporary directory and excludes private state and artwork.
To produce a signed build, supply `DEVELOPER_ID` and `NOTARY_PROFILE` through your
local environment; these refer to an installed certificate and Keychain profile.
The script notarizes and staples the app before creating the final ZIP.

The source archive contains a SHA256SUMS manifest. Binary checksums detect changes
to a known file; they do not prove the absence of vulnerabilities. Apple
notarization also does not guarantee that an app cannot be exploited.

## Current release gates

- Developer ID signing, Apple notarization, ticket validation and local Gatekeeper
  assessment passed for `OVRCAST-0.3.1-macOS.zip` on October 29, 2026.
- Verify the final downloaded artifact and checksums. Keep a separate-Mac
  installation test listed as unperformed until it is actually completed.
- CodexBar 0.81.0 was used for release compatibility checks.
- Independent automated baseline and bounded fix reviews are complete; an
  external human security certification has not been performed.
- Publish the clean source under gitdot5/OVRCAST with private vulnerability
  reporting enabled. See RELEASE_REVIEW.md for the exact validation scope.

See Apple's Developer ID and notarization documentation and GitHub's release guide:

- https://developer.apple.com/developer-id/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
