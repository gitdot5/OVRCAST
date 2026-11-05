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
- [ ] Hosted Intel and Apple Silicon tests pass; full clean universal package build
  is still running in [this workflow](https://github.com/gitdot5/OVRCAST/actions/runs/41937588751).
  The tested runtime commit is `fe3f057`; later documentation changes do not alter it.
- [x] Final packaged signature, notarization, Gatekeeper and private-payload checks.
- [x] Day/Night, offline, Connect/Health/Personalize/About, fresh/recovered setup
  and support preview. Existing Alerts/Computers controls remain; permission
  and physical interaction checks below are separate.
- [x] Valid signed feed/archive accepted; tampered versions rejected.
- [x] Disposable Sparkle installation and helper restart, exact installed-code
  comparison, preserved fixture settings, and separate updated-app demo launch.
  Manual 0.4.3 → 0.5.0 → 0.4.3 launch/rollback also preserves fixture preferences.
- [ ] Standard updater dialog interaction: macOS screen-capture failure prevented
  interactive automation. The programmatic test uses a custom credential-free
  user driver and does not establish the standard dialog experience.
- [ ] Physical-Mac clean installation/upgrade, sleep/wake and notification delivery.
- [ ] macOS 14 and physical Intel validation, separately from Rosetta/hosted CI.
- [ ] Current live Codex and Antigravity readings pass; Claude returns no usable
  reading. A human Claude Code sign-in check has been requested.
- [x] Current candidate launches on both available remote Apple Silicon Macs
  (macOS 26 and 27), with signature, Gatekeeper, resources and private demo checks.
  The initial test retry fixed a truncated SSH transfer, not an application crash.
  The historical 0.3.3 timeout cause was not established by this check.

Do not publish merely because code compiles or Apple notarizes it. Record exact
completed checks and unresolved limits with the candidate artifacts. Provider
sign-in and macOS notification permission require the user’s direct interaction.
This work is a focused first-party change review, not a new independent audit of
all vendored collector code. An opt-in beta test plan follows acceptance; no beta
testers have been contacted or enrolled by this work.

The final candidate ZIP is SHA-256 `6af3aafe29f2cc3d0b14e8f392b307cc13ad39e854686a4e2f06633fc1f7225f`.
Both GUI/collector slices and all Sparkle executables are universal. The collector
code-directory hashes match the installed 0.4.3 baseline in both architectures.
Rosetta GUI execution passes; this is separate from physical Intel testing.
macOS reports notification permission off, so no delivered notification is claimed.
The published and installed app remain 0.4.3. No 0.5.0 release or feed is published.
