# OVRCAST 0.5.0 candidate

Updated November 17, 2026. Build 14 refines usage cards and stale-reading recovery,
following build 13's opt-in local agent access and token history. **Unpublished;
release acceptance is pending.** Version 0.4.3
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

## November 17 build 14 usage-card changes

- Session and Weekly use matching tracks with explicit percentages remaining.
  A passed historical reset no longer hides its last-known Session bar. Current
  reset-pending windows still require a new reading before showing capacity.
- One last-known status and age per card replaces repeated stale warnings.
  Provider/account and device/status have separate alignment and visual weight.
- A neutral recovery panel offers Refresh or connection Setup when no current
  recommendation exists. Historical values never become recommendations.
- An empty current-reading count is neutral instead of green. Current readings
  retain capacity colors and their next-reset details.
- Local fictional-data previews cover stale, fresh, reconnect, Day and Night.
  Refresh-to-current and account-detail navigation were exercised in isolation.
  Full VoiceOver and release-package acceptance remain pending.

Build 13's hosted run passed all three jobs:
https://github.com/gitdot5/OVRCAST/actions/runs/44196832177.
Those results and its signed package are historical evidence. Build 14 needs its
own distribution archive, hosted build and release acceptance; old passes are not
carried into the current readiness record.

## November 17 build 13 changes

- Opt-in local `--agent status` and `--agent recommend` JSON commands. They read
  the GUI's selected saved snapshot without starting the GUI, network requests,
  collectors or job execution. Disabling access is effective on the next command.
- Anonymous snapshot-scoped account/machine/window references and an output
  allowlist exclude identities, credentials, SSH routes and raw provider text.
- Recommendations respect every quota window, stale and failed readings, reset
  boundaries and minimum remaining capacity. Shared account quota is counted once
  across machines. Capacity options are separate by provider; no unsupported
  cross-provider dollar savings or automatic spending is claimed.
- See [AGENT_INTEGRATION.md](AGENT_INTEGRATION.md) for the contract and limitations.
- Opt-in Today / Last 7 days token counters per harness and Mac, with input,
  output and cache components where recorded. Local-only parser projections
  exclude content and identities; partial/missing data stays explicit. Copied
  sessions are not summed across Macs. See [TOKEN_ACTIVITY.md](TOKEN_ACTIVITY.md).

Build 12's three hosted jobs have all passed, including the clean universal package
contract: https://github.com/gitdot5/OVRCAST/actions/runs/42304960992.
That is a verified baseline, not acceptance of the new build 13 runtime. Build 13
must receive fresh source, package, signing and interactive acceptance evidence.

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

Earlier package and hosted results below are historical baselines. The current
build 14 runtime needs fresh acceptance; none of the old package passes are
silently carried forward. Local validation is recorded separately from release
acceptance.

- [x] Build 14 local source tests: 112 Swift and 102 Python checks.
- [ ] Fresh build 14 hosted tests and universal package contract.
- [ ] Final build 14 signing, notarization, payload and packaged-preview checks.
- [ ] Repeat build 13's passing agent/token package checks on build 14, including
  permission revocation, numeric-only projections and unavailable/partial states.
- [ ] Live provider acceptance with consenting testers using their own connections.
  Detailed account and connection results remain private.
- [ ] Notification delivery with the required macOS permissions.
- [ ] Standard updater dialogs and full interactive keyboard/VoiceOver checks.
  Earlier build 13 app controls were exercised using an isolated fictional fixture;
  that is not full VoiceOver or updater acceptance.
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

## Build 12 package results

The exact build 12 ZIP passes Developer ID signature, Apple notarization,
Gatekeeper, universal-binary, resource and private-payload checks. Day/Night,
offline, every settings tab, support and fresh/recovered-setup previews pass.
The Intel GUI slice renders successfully through `open --arch x86_64` under
Rosetta. Manual 0.4.3 → build12 → 0.4.3 fixture launch/rollback preserves preferences.
Signed feed/archive checks accept this package and reject altered copies.

SHA-256: `0de5a21b05f39fda61ab3a274a241de5735375c17c10203633cbb3fd49c5cc13`.

Build 12 test jobs passed on Intel/macOS 15 and Apple Silicon/macOS 26;
the full clean universal package job also passed (verified November 17):
https://github.com/gitdot5/OVRCAST/actions/runs/42304960992
Runtime commit: `97fe9138fafaf8a4247c49f4b5f4d7ac8b14890a`.
Later documentation/readiness updates do not change the tested runtime.

The resource gate remains pending for battery/endurance observations despite the
short CPU/RSS profile. The beta plan is ready but is not an enrolled or completed
beta. Provider acceptance, notification delivery, physical Intel/macOS 14,
actual sleep/network endurance, VoiceOver/keyboard interaction and standard
updater-dialog acceptance still require evidence. No release or feed is published.

Build 12 also launches on both existing remote Apple Silicon Macs using private
demo data, with signature, Gatekeeper and packaged-resource checks. This is a
fresh launch check, not physical Intel/macOS 14 or sleep/wake/endurance evidence.
Per-account provider and permission results are retained only in private evidence.
Do not publish personal connection status, quota readings or account diagnostics.
Beta participants and their hardware must be resolved before enrollment.

The acceptance-record validator was additionally tested with null, boolean and
object evidence values: these cannot count as reviewed evidence. This Python-only
hardening was locally regression-tested after the runtime CI commit; it does not
change the signed GUI or collector.

## Build 13 package results

The signed, unpublished candidate passes universal GUI/helper and minimum-target
checks, strict code signing, packaged-resource checks and the private-payload scan.
Apple notarization is pending; it is not a distribution-ready release.

Candidate SHA-256: `8bd8d42e27c9b602b664411f8f247d0ebbd4ead403bb8a4ca47181ae180c6ec1`. This hash pins the current signed preflight
ZIP. A notarized export will need its own final archive hash and verification.

Packaged token fixtures run with network and real-home access denied. Codex and
Claude counters match the synthetic events, duplicate Claude deliveries are
counted once, valid JSON spacing is accepted, and another backed-up Claude profile
is excluded. Counter output is limited to numeric/date/coverage fields and parser
caches are owner-only. Agent status, recommendation and token commands return
redacted JSON, decline stale routing, respect revocation and leave their saved
inputs unchanged. No account status or personal readings are published here.

Interactive fictional-data checks cover Today/Last 7 days, partial and unavailable
counts, privacy hiding, history opt-out and distinct Studio labels. Full VoiceOver
and standard updater-dialog acceptance remain pending. Disposable 0.4.3 → build 13
→ 0.4.3 launch/rollback preserves fixture preferences and privacy. Signed update
feed/archive checks accept the candidate and reject altered copies.

Runtime source: `dd1dd75e7aca5693c9c47035c549df7a69fcd233`. Both hosted source-test
jobs and the clean universal package contract passed:
https://github.com/gitdot5/OVRCAST/actions/runs/44196832177

All remaining gates in `app/release-readiness.json` still require reviewed passing
evidence. No release, production update feed or installation replacement has been
published by this work.
