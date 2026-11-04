# OVRCAST 0.5.0 candidate

November 4, 2026. **Unpublished; release acceptance is pending.** Version 0.4.3
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

## Acceptance checklist

- [x] Local Swift/Python suites (81 Swift and 99 Python) and clean source export.
  Both suites passed November 4; subsequent source changes require rerunning affected checks.
- [ ] Hosted Intel and Apple Silicon tests; full clean universal package build.
- [ ] Final packaged signature, notarization, Gatekeeper and private-payload checks.
- [ ] Day/Night, offline, all settings, fresh/recovered setup and support preview.
- [ ] Valid signed feed/archive accepted; tampered versions rejected.
- [ ] Disposable installation update/restart and preserved preferences.
- [ ] Physical-Mac clean installation/upgrade, sleep/wake and notification delivery.
- [ ] macOS 14 and physical Intel validation, separately from Rosetta/hosted CI.
- [ ] Current live Codex, Claude and Antigravity readings.
- [ ] Resolve the previously observed separate-Mac launch timeout.

Do not publish merely because code compiles or Apple notarizes it. Record exact
completed checks and unresolved limits with the candidate artifacts. Provider
sign-in and macOS notification permission require the user’s direct interaction.
This work is a focused first-party change review, not a new independent audit of
all vendored collector code. An opt-in beta test plan follows acceptance; no beta
testers have been contacted or enrolled by this work.
