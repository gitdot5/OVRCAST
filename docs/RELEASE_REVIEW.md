# OVRCAST 0.3.3 release review

Release: https://github.com/gitdot5/OVRCAST/releases/tag/v0.3.3
Reviewed October 29, 2026. Public preview, macOS 14+, Apple Silicon and Intel.

## Verified release artifact

- The original segmented capacity-ring icon is embedded in the native macOS
  bundle and displayed by the board headers, setup and About screen.
- Strict Developer ID signature, hardened runtime, Apple notarization, stapled
  ticket and Gatekeeper checks passed for the exact app ZIP.
- The packaged app rendered successfully in Day and Night appearances, with
  the three bundled provider marks and per-account next-reset schedule.
  Each scheduled reset shows its window, countdown, local date/time and time zone.
  Passed, stale and unknown timestamps do not claim a confirmed refill.
- The universal executable includes arm64 and x86_64 architectures. Runtime
  checks passed on Apple Silicon and with the Intel slice under Rosetta.
  Physical Intel hardware was not exercised.
- The exact ZIP passed signature, ticket and Gatekeeper assessment on a
  separate Apple Silicon Mac running macOS 26.6.2. GUI and diagnostic launches
  timed out without a snapshot/diagnostic file or recent crash report. Separate-
  Mac runtime remains unverified and requires console inspection.
- The release source is an allowlisted export with example configuration,
  original artwork, license notices and integrity manifests. Private local
  configuration/state, private provider/device images and original private Git
  history are excluded.
- 89 Python and 50 Swift tests passed for 0.3.3, including provider fallback,
  supported Claude source, auth-state and window-preference regressions. CodexBar 0.81.0 was used for
  compatibility review and remains a separately installed dependency.

## Independent automated security review

An independent baseline fully reviewed the initial release's 60 text files and
found one low-severity resource-exhaustion issue (CWE-400) in optional legacy
SSH output buffering. A bounded follow-up by the same reviewer confirmed the
0.3.1 fix: subprocess stdout/stderr share a 4,000,000-byte limit, local snapshots
are bounded before decoding, process deadlines remain enforced, and failures
retain last-good readings. Regression tests exercise the output boundaries,
combined streams, timeout and oversized local snapshot cases.

No other reportable source finding was established in that review. That review
predates the 0.3.2 reset UI and public provider-image packaging changes; no new
independent security scan was performed for this update. The final
capacity-ring SVG contains static local vector geometry; it does not load external
resources or execute scripts. This is an automated source review, not an
external human security certification. Binary artwork forensics, macOS and
external CodexBar/provider implementations are outside the source audit.

## Known behavior

Provider output and sign-in availability can change. Fields absent from a
source stay Unknown. Native collection runs while the app is open. Optional
SSH connections require existing trusted aliases; OVRCAST does not configure
SSH access or copy credentials. Privacy mode hides identities, computer names
and credit balances; percentage quotas and saved-reset counts remain visible.

Verify the final download with the SHA-256 manifest attached to the release.

See [the engineering sweep](ENGINEERING_REVIEW.md) for fixed findings, live
provider results, UI coverage and the remaining setup/validation gaps.
