# OVRCAST 0.3.0 release review

Release: https://github.com/gitdot5/OVRCAST/releases/tag/v0.3.0
Reviewed October 28, 2026. This is the first public preview.

## Verified locally

- 85 Python tests and 37 Swift tests passed.
- Clean source export contains only allowlisted files, example configuration,
  original artwork and license notices. Private configuration, local state,
  private provider/device images and all original Git history are excluded.
- The app ZIP contains an Intel and Apple Silicon universal binary with
  hardened runtime, Developer ID signature, Apple notarization and stapled ticket.
- Strict code-signature validation, stapled-ticket validation and Gatekeeper
  assessment passed on the extracted ZIP. Packaged demo launch passed.
- Fresh-home onboarding was checked on the same Mac with a sandbox preventing
  access to the development home. The installed CodexBar was still detected;
  this does not establish a missing-companion installation test.
- Reviewed collection/parsing, stale and unknown readings, deduplication,
  reset inventory, credit display, private storage, support-report redaction,
  optional SSH commands, source export, packaging and license notices.
- CodexBar 0.81.0 was installed for compatibility testing. It is a separate
  dependency and is not bundled in the download.

## Limits and known behavior

- No separate-Mac installation test, missing-companion GUI test, or independent
  security audit is claimed.
- Provider availability depends on CodexBar and the provider's CLI sign-in.
  Provider output can change. Missing reset inventories or credit pools remain
  Unknown; this app cannot report fields the source does not provide.
- Native collection runs while the app is open. SSH requires an existing
  trusted alias. OVRCAST does not configure network access or credentials.
- Optional legacy Python collection is included for existing scripted installs;
  the native downloadable app does not need Python or a development checkout.
- Privacy mode hides identities, names and credit balances. Percentage quotas
  and saved-reset counts remain visible.

Use the checksums attached to the release to verify the exact download.
