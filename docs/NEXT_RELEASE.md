# OVRCAST 0.5.0 candidate

Updated November 22, 2026. Build 18 preserves existing standalone provider
selections and carries forward the verified Claude quota-window fix. **Unpublished;
release acceptance is pending.** Earlier results below are historical and do not
establish acceptance of build 18.

## November 22 build 18 fleet compatibility

- Standalone agents can retain their selected providers while using the bundled
  OVRCAST collector, without reading CodexBar's provider configuration. Empty or
  invalid selections do not launch a provider or modify its CLI path.
- The board labels saved-reset inventory separately from the next usage reset,
  avoiding an ambiguous “Resets unknown” beside known reset times.
- Build 17 passed all three hosted jobs in workflow 45093812091. Its Claude
  parser and signed update installation/relaunch are verified
  separately. Those results do not establish acceptance of the build 18 archive.

## November 22 build 17 Claude quota accuracy

- A current Claude usage panel can report weekly and model limits without a
  Session allowance. The first weekly percentage now stays Weekly; it is never
  copied into an unreported Session window.
- Valid weekly-only, session-only and model-only readings retain their actual
  window types. Advertised windows whose values are still loading require a
  bounded retry of the same source, rather than a partial current reading.
- Capture completion recognizes labeled weekly values, so a weekly-only panel
  can finish without waiting for a Session label that is absent.
- Collector regressions now run directly against the maintained fork on both
  hosted architectures. The app adapter also has a weekly-only contract fixture.
- The prior build 16 hosted workflow completed all three jobs, including the
  clean universal package contract. That is historical build 16 evidence.

Build 18 acceptance is tracked in `app/release-readiness.json`. Apple Developer
sign-in/agreement review remains pending before notarization can proceed.

### Build 18 verification scope

Runtime: `2d8e894750665605de8aa356d3bf1078a9e7acb6`.

- 115 app Swift, 10 collector Swift and 106 Python tests pass. Both hosted
  architecture test jobs and the clean universal package/resource job pass in
  [the build 18 workflow](https://github.com/gitdot5/OVRCAST/actions/runs/45097870599).
- The signed universal preflight ZIP passes nested signatures, minimum-OS
  metadata, resources and private-payload checks. Packaged token and agent
  fixtures pass with network and real-home access denied. Signed feed/archive
  checks accept the candidate and reject altered copies.
- Desktop-context checks on three existing Apple Silicon Macs return current
  readings from all seven configured connections with expected-account matches.
  The GUI displays their reported quota windows and next reset times. Connection
  identities, raw captures and quota values remain in private acceptance evidence.
- The standard updater offers build 18 to a separate build 17 installation.
  Cancel/retry, download, extraction, installation and relaunch pass. Both installed
  executables match the candidate, strict signing remains valid, and the owner's
  provider, privacy, computer, notification and appearance preferences are preserved.
  This uses a signed loopback test feed; no public feed is changed.
- A disposable 0.4.3 → build 18 → 0.4.3 launch preserves exact preferences and
  privacy. The signed build 18 GUI delivers its test alert to Notification Center;
  visible banners and Focus behavior are separate observations.
- Both existing remote Apple Silicon Macs launch the exact staged candidate with
  fictional data and pass signing/resource checks. The GUI and helper's Intel
  slices also run locally through Rosetta. These are not physical Intel or
  macOS 14 runtime acceptance.
- The reviewed support report saves locally and passes the actual field and
  private-identity checks. Nothing is sent automatically. In existing-collector
  mode, its connection rows describe the saved built-in connection settings;
  the current-reading count describes the displayed fleet.
- A 303-second owner-GUI sample averages 0.046% CPU, with a 2.8% peak and RSS
  from 131.77 to 137.17 MiB (137.27 MiB peak). This is a short observation,
  not battery, leak or overnight acceptance.

The candidate is **not ready for public distribution**. Apple notarization and
final archive/update acceptance, physical Intel/macOS 14, full keyboard/VoiceOver,
sleep/network/endurance, battery/resource observations and opt-in beta results
remain required. Agent and token-history permissions remain off in the owner's
app. The existing Applications installation and public release are unchanged.

## November 21 build 16 Claude profile continuity

- A desktop-session check found that an existing connection could be signed in
  under an OVRCAST-managed profile while the default Claude profile was signed out.
- Built-in quota and token-history collection preserve the profile selected by
  an existing OVRCAST collector. An explicit profile in the app environment,
  including an explicit default profile, takes priority.
- Connect Claude uses the same profile and CLI path as collection. Migration reads
  only the profile selector from the existing OVRCAST LaunchAgent; it does not
  import credentials or unrelated environment settings.
- Fresh installs retain Claude Code's ordinary profile. Collection does not retry
  another account after a failed connection.
- Apple rejected the notarization export because a required legal agreement is
  missing or expired. Developer account sign-in and agreement review remain
  pending; no notarization submission was accepted and nothing is published.

### Build 16 verification scope

Runtime: `14968a3c2901e2defeaf3f031602abe536712196`.

- 115 Swift and 102 Python tests pass. Both hosted source-test jobs and the
  [clean universal package job](https://github.com/gitdot5/OVRCAST/actions/runs/44958900331)
  passed.
- The local Developer ID signed universal candidate passes strict nested signing,
  resource, minimum-OS metadata and private-payload checks. Isolated token-counter
  and agent fixtures pass. Signed feed/archive checks reject altered copies.
- Desktop-context queries match expected Claude and Codex accounts on all three
  configured Macs. The actual signed GUI receives current local readings and
  delivers its test notification to Notification Center.
- Claude captures sometimes omit quota labels or the general weekly window.
  A successful reading is not sufficient evidence of complete limit capture;
  live-provider acceptance remains pending while this is investigated.
- A disposable 0.4.3 to build16 to 0.4.3 launch preserves exact preferences and
  privacy. The owner app and its original collection mode are restored after
  testing. Agent and token-history permissions remain off.
- Notarization and the final accepted archive/update installation remain pending,
  together with physical Intel/macOS 14, full accessibility, endurance/resource
  and opt-in beta acceptance. Local fixtures do not establish those outcomes.

## November 21 build 15 Claude connection fix

- Read Claude quota through the currently signed-in Claude Code session. Direct
  access to Claude Code's raw OAuth credentials is not required or enabled.
- Claude uses the active local session rather than a configured token-account
  override. A failed connection does not silently switch sources or accounts.
- The existing standalone collector follows the same route and preserves its
  configured Claude profile. Codex and Antigravity collection remain unchanged.
- Live desktop-session diagnostics returned current, expected-account Claude
  readings on all three configured Macs through the signed collector's CLI route.
  SSH-only auth checks did not represent desktop-session access.
- Notification permission is enabled and the signed build 14 baseline delivered
  a test alert to Notification Center. Repeat delivery on the final build 15.

Build 15 required fresh source, hosted, package and live acceptance evidence.
The current candidate's acceptance record is `app/release-readiness.json`.

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
- Device symbols adapt to Day/Night. Pending or missing readings use neutral status
  color. Long recommendation labels preserve the percentage, and three quota
  windows stack vertically so their labels remain readable.
- Local fictional-data previews cover stale, fresh, reconnect, Day and Night.
  Refresh-to-current and account-detail navigation were exercised in isolation.
  November 20 previews also cover long names, zero/full allowance, three windows,
  reset-pending, unreadable and empty states. Local tests pass 112 Swift and 102
  Python checks. Full VoiceOver and release-package acceptance remain pending.

Build 13's hosted run passed all three jobs:
https://github.com/gitdot5/OVRCAST/actions/runs/44196832177.
Those results and its signed package are historical evidence. Build 14 evidence
is recorded separately below; earlier passes were not carried forward into its
readiness record.

### November 20 build 14 package checks

Runtime commit: `82366b710fb1fb065c3cbdb2dbba03b691e228a3`.
The local Developer ID signed universal candidate passes strict signature,
minimum-macOS, resource and private-payload checks. Network/home-denied token
parser and agent fixtures pass, including redaction, unchanged input files,
revoked permissions and stale-routing rejection. Signed feed/archive checks
accept the candidate and reject altered copies.

A disposable 0.4.3 → build14 → 0.4.3 launch/rollback preserves preferences and
privacy. Both existing remote Apple Silicon Macs launch this exact candidate
with demo data and pass signature/resource checks. These checks do not establish
live-provider, physical Intel/macOS 14, updater-dialog or endurance acceptance.
The build 14 Intel GUI slice also launches and renders through Rosetta with
fictional data and privacy mode enabled.
The local Cmd+R refresh shortcut also transitions a stale fictional fixture to
current readings with reset times; full keyboard/VoiceOver acceptance is pending.

The candidate is not notarized or installed. Its generated signed feed is a
local fixture; the configured public feed is not yet published. Initial feed
publication and final download/signature checks follow [UPDATES.md](UPDATES.md).
Both build 14 hosted source jobs and the clean universal package/resource contract
passed:
https://github.com/gitdot5/OVRCAST/actions/runs/44823607900.

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

## Build 14 acceptance baseline

The checklist below records build 14. Build 15 has a separate readiness record;
these passes are not carried forward. Local validation remains separate from
release acceptance.

- [x] Build 14 local source tests: 112 Swift and 102 Python checks.
- [x] Fresh build 14 hosted tests and universal package contract.
- [ ] Final build 14 signing, notarization, payload and packaged-preview checks.
- [x] Repeat build 13's passing agent/token package checks on build 14, including
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
