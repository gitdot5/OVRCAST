# OVRCAST 0.4.1 release review

This patch replaces generic privacy labels with recognizable Mac types on
account cards, computer filters, recommendations, connection help and privacy
exports. Local hardware is read from macOS once; only its recognized family is
retained. Remote names such as Mini and Studio become Mac mini and Mac Studio.
No remote hardware probe or SSH change is introduced. Unknown remote types
remain generic rather than guessing a model. Duplicate types get stable numbers.
Custom computer names and account identities stay hidden in privacy mode.

Validation for this change: 57 Swift tests, five source-export tests, a clean
universal GUI build, packaged privacy previews, Developer ID signature,
notarization, stapled-ticket and Gatekeeper checks. The final archive and
installed copy are compared, and release asset downloads are hash-verified.
Physical Intel hardware and macOS 14 runtime remain untested.

The collector is unchanged from 0.4.0. Its pinned source manifest and both executable code-directory hashes are verified against
that release; notarization refreshes signing timestamps. The retained review below describes
that collector's existing validation and limits.

## OVRCAST 0.4.0 collector baseline

Release: https://github.com/gitdot5/OVRCAST/releases/tag/v0.4.0
Reviewed October 29, 2026. Public preview, macOS 14+, Apple Silicon and Intel.

OVRCAST includes its own maintained collector, derived from CodexBar v0.81.0
at the revision recorded in `vendor/OVRCASTCollector/UPSTREAM.json`. No separately
installed CodexBar app or CLI is required. Provider software and sign-in remain
necessary. Existing CodexBar-specific token-account configuration is not imported.

## Verification scope

The exact app ZIP passed strict Developer ID signature validation, hardened
runtime resource execution, Apple notarization, stapled-ticket validation and
Gatekeeper assessment. Both the GUI and nested helper contain arm64 and x86_64
slices with macOS 14 minimum deployment metadata. The helper links only macOS
system libraries, and its bundled resources and dependency notices are present.
The source archive uses explicit file allowlists and integrity manifests.

- 94 Python and 52 Swift tests passed.
- Packaged resource execution and configuration isolation passed with a fresh
  home, restricted PATH and an invalid CodexBar configuration override.
- Server and mutation entrypoints were rejected.
- Day/Night previews, fresh setup and Connect/Personalize/Alerts/Computers/About
  navigation passed. The Connect screen reports Built-in collector ready and
  provides all three provider connection controls; privacy checks passed.
- The GUI and collector resource runtime passed under Rosetta as x86_64.
- Live Codex and Antigravity reads returned current quota windows and reset
  timestamps through the bundled helper. Claude correctly reported sign-in
  required; live Claude usage remains unverified.

Final asset downloads are compared with the release's SHA-256 manifest before
publication. The maintainer retains the artifact checks and counts-only evidence.

## Known limits

Claude needs a Claude Code OAuth connection; a Claude Desktop sign-in alone
may not supply it. Opening a provider app or login command is not proof that
sign-in completed. Missing fields remain Unknown, and a passed reset timestamp
waits for a fresh provider reading before claiming restored allowance.

Native collection runs while the app is open. Optional remote computers must
have OVRCAST 0.4.0 installed and their own provider connections. Existing trusted
SSH aliases remain required. Existing remote collectors are not silently upgraded.

This update does not establish successful runtime operation on the separate Mac
whose 0.3.3 launch timed out. Physical Intel hardware and macOS 14 runtime remain
untested. Local Intel-slice execution under Rosetta is a different check.
Actual notification delivery and interactive authentication are not automated.
Updates remain manual: replace the app in Applications with a newer release.

The earlier independent automated security review and bounded SSH fix concern
first-party code. They predate this bundled fork; no independent audit of all
vendored collector code was performed. Apple notarization and runtime tests are
not a security certification.

See [the engineering review](ENGINEERING_REVIEW.md) and verify downloads against
the SHA-256 manifest attached to this release.
