# OVRCAST 0.4.1 engineering review

The machine-label change has 57 passing Swift tests, including recognized
families, hardware-report parsing, duplicate types, custom-name privacy and
remote unknown-type handling. Five source-export boundary tests also passed.
The GUI is rebuilt from the clean allowlisted source for both architectures.
The collector source and executable code are unchanged from 0.4.0.

## OVRCAST 0.4.0 collector baseline

Reviewed October 29, 2026. Public preview; macOS 14+, Apple Silicon and Intel.

## Change and ownership

OVRCAST now builds and ships its own collector from a pinned CodexBar v0.81.0
MIT source fork. The app resolves only its own nested helper. The optional
legacy collector also resolves an OVRCAST helper, with no external CodexBar
fallback. The source export includes local copies of the three package
dependencies, provenance, source hashes and required notices. No remote Swift
package fetch is needed. CodexBar itself is not installed or updated by OVRCAST.

Collector-owned configuration, caches, defaults and keychain services use
OVRCAST namespaces. Provider-owned sign-in locations remain supported.
The normal connection flow opens official provider software. Claude login
runs only after an explicit Connect action; automated tests use an inert fixture.
Existing CodexBar token-account settings are not silently copied.
The helper entrypoint rejects upstream server and mutation commands. User
provider plugins are not activated. Internal JSON schema names remain compatible.

## Automated checks

- 94 Python tests passed: private-data guards, legacy collection, failure
  isolation, last-good retention, SSH bounds and explicit source-export hashes.
- 52 Swift tests passed: bundled-helper lookup, shell argument quoting with
  metacharacters, provider fallback/auth-state handling, reset schedules,
  privacy, alerts, freshness, deduplication and window preferences.
- The vendor allowlist verifies 1,109 files. Unlisted private files and build
  outputs are excluded; tampering causes an export failure.
- The collector compiles for arm64 and x86_64 with macOS 14 deployment metadata.
  Its resource smoke probe exercises the packaged JavaScript runtime.

Day/Night, fresh setup, all Settings tabs, Rosetta GUI/helper execution and live
Codex/Antigravity reads passed. Claude reported sign-in required. Strict signature,
notarization, stapled-ticket and Gatekeeper checks passed. Detailed results are recorded in
[the release review](RELEASE_REVIEW.md).

## Limits and previous evidence

The prior [0.3.3 engineering sweep](ENGINEERING_REVIEW_0.3.3.md) covered the HTML
board, additional native tabs and a separate-Mac assessment. Its separate-Mac
runtime launch timed out without diagnostics; the cause remains unconfirmed.
That result does not count as a successful 0.4.0 launch on another Mac.
Physical Intel hardware, macOS 14 runtime, notification delivery and interactive
provider authentication are not covered by this update’s automated tests.

The prior independent security review covered first-party code before this
fork was bundled. No new independent security audit of the vendored collector
was performed. Compilation and runtime checks do not constitute such an audit.
