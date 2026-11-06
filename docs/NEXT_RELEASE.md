# OVRCAST 0.5.0 candidate

Updated November 6, 2026. Build 12 supersedes the earlier build 11 candidate. **Unpublished; release acceptance is pending.** Version 0.4.3
remains the public release. This document records candidate scope and does not
claim completed hardware, provider, notification or updater installation checks.

## Changes

- Optional signed in-app updates using pinned Sparkle 2.10.1. Signed feed and
  archive checks are mandatory; system profiling and automatic updates start off.
- First launch chooses providers, opens their own sign-in software and requires
  an actual current local usage reading before setup can finish.
- Health shows provider/Mac state, last successful reading and scheduled retry.
  Opening sign-in is never treated as a verified connection.
- Refreshes run independently for providers and Macs, publish completed results
  immediately, preserve failed sources as last known, and back off repeated
  automatic failures to a maximum 30-minute interval. Manual retry bypasses delay.
- Wake and network restoration request a refresh; repeated recovery events are
  coalesced. An unavailable remote cannot replace a current local reading.
- Support reports have a review window before copy/save and use a strict field
  allowlist without identities, custom names, credentials, balances or raw errors.
- Optional menu-bar capacity and conservative local forecasts. Forecasts require
  at least three continuous readings over 15 minutes in one reset window, exclude
  stale/reset/discontinuous data and remain explicitly labeled estimates.
- Notification test control and unchanged bundle/data/provider compatibility.

## November 6 build 12 changes

- Distinguish unreadable Claude credentials, local credential permission failures
  and provider rate limits. All help remains sanitized and no credentials are changed.
- Provider contract fixtures cover the three providers, successful quotas, expired
  and unreadable sign-in, Keychain denial, rate limiting and incompatible schemas.
- A wake/network event inside the recovery throttle is deferred instead of lost.
  Repeated events coalesce into one retry; stop cancels pending work.
- Named toolbar controls, privacy/selection accessibility states, keyboard actions,
  combined account rows and Reduce Motion support.
- Reuse timestamp parsers and a limited in-memory timestamp cache. Freshness still
  checks the current clock; dates in the cache cannot make stale usage current.
- Publication readiness requires reviewed evidence and the exact archive hash.
  A pending gate prevents `script/check_release_readiness.py` from passing.

## Acceptance checklist

Build 11's signed-package, remote launch and updater results below are historical
baselines, not acceptance of changed build 12. New source needs its own package/CI
checks. The prior runtime's full CI did pass on all three jobs:
https://github.com/gitdot5/OVRCAST/actions/runs/41937588751

- [x] Build 12 local source tests: 92 Swift and 102 Python checks.
- [ ] Fresh build 12 hosted tests and universal package contract.
- [ ] Final build 12 signing, notarization, payload and packaged-preview checks.
- [ ] Live Claude reading after human sign-in; official Claude Code status was
  signed out during the November 6 check. No automatic sign-in was attempted.
- [ ] Notification delivery after the user's macOS permission step.
- [ ] Standard updater dialogs and interactive keyboard/VoiceOver checks. The
  computer-use tool stalled and was interrupted; no successful UI action is claimed.
- [ ] Physical Intel/macOS 14 and actual sleep/wake/network endurance.
- [ ] Opt-in beta participants and scenario results. The plan and invitation are
  prepared in [BETA_TEST_PLAN.md](BETA_TEST_PLAN.md); nobody has been enrolled or contacted.

### Resource use

A 35-second cached-data benchmark used separate ad-hoc test bundles and fictional
accounts, with provider collection and alerts disabled. After timestamp parsing
reuse, the 10-account sample averaged 0.064% CPU and about 46.94 MB RSS; the
100-account sample averaged 0.892% CPU and about 47.30 MB RSS. Before the change,
those short samples averaged 0.46% and 2.812% CPU respectively. Measurements are
observational, not statistically controlled battery, rendering or overnight tests.
RSS growth after warmup was 0.03 MB and 0.17 MB in these short samples.

See [PROVIDER_MAINTENANCE.md](PROVIDER_MAINTENANCE.md) for the repeatable compatibility
review and fixture process, and [UPDATES.md](UPDATES.md) for the publication gate.

Do not publish merely because code compiles or Apple notarizes it. Record exact
completed checks and unresolved limits with the candidate artifacts. Provider
sign-in and macOS notification permission require the user’s direct interaction.
This work is a focused first-party change review, not a new independent audit of
all vendored collector code. An opt-in beta test plan follows acceptance; no beta
testers have been contacted or enrolled by this work.

## Build 11 historical baseline

The earlier build 11 ZIP was SHA-256
`6af3aafe29f2cc3d0b14e8f392b307cc13ad39e854686a4e2f06633fc1f7225f`.
It passed notarization, Gatekeeper, private-payload, Rosetta, both remote Apple
Silicon launches, tamper rejection, disposable programmatic updater installation
and manual upgrade/rollback. Those tests do not validate changed build 12 code.
The collector source remains unchanged; its code hashes matched installed 0.4.3
in both architectures. The published app remains 0.4.3; 0.5.0 remains held.
