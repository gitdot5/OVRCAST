# Signed updates and recovery

OVRCAST 0.5.0 introduces Sparkle 2.10.1, pinned to the official package and binary
checksum. Earlier releases need one manual installation to adopt the updater.
Choose Check for Updates from the menu or Settings → About. Automatic checking
and automatic downloading/installing are separate opt-in controls, initially off.

The public feed is `https://raw.githubusercontent.com/gitdot5/OVRCAST/main/appcast.xml`.
Release archives are hosted in the official GitHub repository. The updater requires
an Ed25519-signed feed and verifies the update archive before extraction. Apps also
retain Developer ID signing and Apple notarization. System profiling is disabled;
no provider credentials, account identities or usage readings are added to requests.
GitHub still receives normal network request metadata, including IP address and
the updater’s app/version user agent. There is no OVRCAST usage-data backend.

The private update signing key stays in the maintainer’s macOS Keychain under the
dedicated `com.weekthink.ovrcast.updates` account. Only the public key is in the app.
Do not export private keys into the repository, build environment or download host.

## Release procedure

1. Run tests, export the clean source and build the universal app. Preserve the
   framework’s relative symlinks. Sign nested updater components from inside out
   with `script/sign_bundle.py`; preserve the downloader/installer entitlements.
2. Notarize and staple the final app. Verify the exact ZIP with
   `python3 script/verify_release.py ARCHIVE --notarized`.
3. Stage only the final ZIP and its release-note text in an archive directory.
   Run `script/generate_update_feed.sh SPARKLE_BIN ARCHIVE_DIRECTORY` using the
   official pinned Sparkle distribution tools. This signs the archive, notes and
   feed using the Keychain. Verify signatures and prove altered files are rejected.
4. Test an update of a separate disposable installation. Check process restart,
   version, signatures and preserved settings. Never use a developer feed in the
   shipping app. Complete the other candidate acceptance checks before publication.
5. Publish the exact verified archive, compare anonymous download hashes, then
   publish its generated signed `appcast.xml` unchanged. Never hand-edit a signed
   feed. Retain the previous signed release for manual recovery.

## Recovery

If an update fails, quit OVRCAST, download the previous signed release from the
official GitHub releases page, and replace the app in Applications. Keep the
existing `UsageBoard` data folder. No credential copying or new provider sign-in
should be necessary solely for replacing the app. New preferences use defaults
when absent, while prior versions ignore unknown fields. Damaged preferences are
preserved separately; do not delete the recovery copy while troubleshooting.

There is no automatic downgrade. Do not disable Gatekeeper, change bundle IDs,
remove provider Keychain entries, or publish a lower build number to force rollback.
