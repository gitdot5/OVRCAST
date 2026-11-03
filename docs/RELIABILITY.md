# Reliability work for 0.4.2

Reviewed November 3, 2026. This remains a public preview. Automated checks cannot
establish that every provider account or Mac configuration will always work.

## Fixed failure paths

- Missing fields in older preferences use defaults while retaining saved privacy,
  aliases and remote connections. Provider lists and numeric settings are normalized.
- Unreadable preferences are preserved in an owner-only recovery copy before
  defaults can replace them. Privacy mode stays on during recovery so cached
  identities are not exposed. If recovery cannot be saved, preference writes stay
  blocked until the storage problem is fixed and OVRCAST is restarted.
- Failed settings/history/snapshot writes appear in Settings. A refresh does not
  report that readings were saved when persistence failed.
- Changing providers, the local computer name or remote connections during a
  refresh causes obsolete results to be discarded before publishing snapshots.
- Selecting no providers gives setup guidance without clearing existing readings.
  Removing a provider resets a now-invalid selected tab to Overview.
- Provider failures retain last-known local readings, exclude them from current
  availability/recommendations, and label cached quota bars as last known.
  Timeout and missing-tool messages give a specific next action.
- Build-only mode no longer closes the installed app or starts live collection.

## Repeatable checks

`Reliability` runs Python and Swift tests on GitHub-hosted Intel/macOS 15 and
Apple Silicon/macOS 26 runners. A separate job builds the complete universal app
from the clean source export, verifies signatures, deployment metadata, both
architecture slices, icons, license notices, URL registration and collector
resources, and checks that unsupported mutation/server commands are rejected.
No provider authentication or usage requests are part of this workflow.

The release verifier can also check Apple notarization and Gatekeeper:

```sh
python3 script/verify_release.py dist/OVRCAST-0.4.2-macOS.zip --notarized
```

The version and build number come from `app/version.json`. Exported source
includes this workflow and the verifier. Release binaries still need Developer ID
signing, Apple notarization and final downloaded-asset hash verification.

## Validation and remaining launch gates

Local suites: 68 Swift and 94 Python tests passed. The new cases cover settings
migration/recovery, storage failure, connection changes during collection,
empty selection, stale-reading retention, missing provider tools and real process
timeouts. Packaged offline previews use `--demo --demo-offline --privacy` with
fictional data; they never read provider accounts.

Hosted CI and the exact signed/notarized artifact are separate acceptance checks;
their completed results are linked in release notes. Previous live Codex and
Antigravity readings belong to the 0.4.0 baseline, not a new provider certification.

Before removing the preview label, complete a clean-user installation, upgrade,
sleep/wake and notification-delivery check on the oldest supported macOS version
and both hardware families. The previous separate-Mac launch timeout still needs
console inspection. Complete a live Claude Code OAuth usage check with the user
signing in directly; do not copy tokens or authenticate automatically.

## Next product priorities

1. Signed automatic updates with a verified update feed and a rollback path.
2. A small opt-in beta group covering different providers, plans and macOS versions.
3. Structured connection health with safe support reports and release-specific
   troubleshooting; keep account credentials and raw diagnostics out of reports.

The app has no telemetry backend. These changes do not claim a new independent
security audit of the vendored collector.
