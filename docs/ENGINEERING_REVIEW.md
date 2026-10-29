# OVRCAST 0.3.3 engineering sweep

Reviewed October 29, 2026. This is an engineering review and automated/runtime
validation of a public preview, not a guarantee that every environment works.

## Findings fixed

1. **Default provider connections were skipped.** Native collection always
   requested configured token accounts. CodexBar 0.81.0 returned no configured
   token accounts for Antigravity even though its default connection worked.
   Collection now retries the default connection only for that exact error.
   Successful multi-account readings and authentication failures are not retried.
2. **Claude used an unsupported source.** The CLI source returned no available
   fetch strategy. Claude now uses the supported OAuth source. Missing Claude
   Code credentials correctly appear as sign-in required. Connection guidance
   no longer suggests that a Claude Desktop sign-in necessarily supplies this
   usage connection.
3. **The release omitted its refresh URL registration.** The packaged app now
   registers `usageboard://`, matching the development bundle. The final
   extracted package contains the expected URL type and scheme.
4. **Demo floating-window settings used the installed app's defaults.** Window
   mode now uses the store's own preference domain; demo frame autosaving is
   disabled. Tests verify isolation between injected preference stores.

## Completed checks

| Area | Evidence |
| --- | --- |
| Python suite | 89 tests passed, including collection failures, last-good retention, bounded SSH output, source export and HTML escaping |
| Swift suite | 50 tests passed, including six new integration regressions, reset schedules, freshness, deduplication, recommendations, privacy and alert rules |
| Live native collector | Codex and Antigravity returned current readings and reported reset times; no account identities or balances retained in sweep logs |
| Native UI | Settings, Personalize, Alerts, Computers and About opened through accessibility actions; About displayed version 0.3.3 |
| Windows/privacy | Floating/full-board diagnostics passed; About accessibility data did not expose example account identities in privacy mode |
| Local launch matrix | Day/Night on arm64; x86_64 launch under Rosetta; fresh application-data home with zero accounts/history and setup visible |
| HTML board | Provider/device filters, details dialog, Escape, search empty state, clear filters, theme persistence, provider images and capacity sort passed in Chromium |
| Reset handling | Earliest reported window, exact local time/time zone, passed/missing/stale values and sub-minute resets tested; previews showed the correct DST time-zone change |
| Distribution | Developer ID signature, Apple notarization, stapled ticket, Gatekeeper assessment, universal slices, macOS 14 deployment metadata, icon/provider resources and ZIP integrity passed |
| Source boundary | Allowlisted source export, privacy scanner and file-integrity manifest passed; private configuration, history, provider sessions and extracted local artwork excluded |

## Remaining setup and validation limits

- The local Claude OAuth usage connection reports missing credentials. Live
  Claude usage is **not verified**. Authenticate Claude Code or configure the
  account in CodexBar, then check again. OVRCAST does not complete authentication.
- On a separate Apple Silicon Mac running macOS 26.6.2, the exact ZIP passed
  checksum, signature, ticket and Gatekeeper assessment. Normal GUI launch and
  an executable diagnostic launch timed out before producing a snapshot or
  diagnostics; no recent OVRCAST crash report was found. Remote GUI accessibility
  was unavailable. The cause is unconfirmed and requires console inspection.
  This sweep does **not** count the separate-Mac first-run or missing-companion
  runtime checks as passed. Existing provider sessions were left intact.
- Rosetta exercises the Intel executable on Apple Silicon; physical Intel
  hardware and macOS 14 were not exercised.
- Notification decision rules passed unit tests. Actual notification delivery,
  provider authentication and remote interactive sign-in were not exercised.
- The prior independent automated security baseline and bounded SSH fix review
  remain separate evidence. No new independent security scan or external human
  security certification was performed for this engineering sweep.

Published archives are verified against the release's SHA-256 manifest.
