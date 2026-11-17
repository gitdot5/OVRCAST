# Daily and weekly tokens

Build 13 adds **Token activity…** to the menu and **Tokens** to the full board.
Enable **Settings → Connect → Token history → Read local token counters** first.
Collection starts off. Turning it off stops further scans and removes the local
counter file shared with your configured Macs. Account quota collection is separate.

Choose **Today** or **Last 7 days**. Seven days means today plus the preceding six
calendar days, not a subscription reset week. Each source Mac's timezone controls
its day boundaries. Figures appear per harness and computer, with input, output,
cache-read, cache-write and source-reported total tokens where available.

Codex, Claude Code and Antigravity use their recognized local records through
OVRCAST's maintained parser fork. OVRCAST exports only numeric counters, dates,
timezone and coverage. Prompts, responses, project/session names, account
identities, file paths and model names are not exported. Pricing refreshes,
other-harness merging and credential fallback are disabled for this command.
Local parser caches stay on the source Mac. Source-reported totals are preserved;
cache components must not be added to them a second time.

Local history is not necessarily account-wide: deleted or copied logs, another
machine, other profiles and unrecognized records can affect coverage. Partial
readings are labeled recorded subtotals. An absent counter or unreadable history
is **Unavailable**, not zero. Zero is shown for an established empty scan or an
explicit zero counter. Old readings are labeled **Last known**. Privacy mode hides
the counts in the app.

Configured Macs publish a local-only counter snapshot through the existing
owner-only OVRCAST data directory. Reading it uses the same existing SSH routes;
OVRCAST opens no new listener. Each remote needs a compatible OVRCAST app with
token history enabled. Older apps or missing permission show unavailable history.
Each Mac remains separate: copied sessions may overlap and no fleet total is
claimed without event-level deduplication. Token counts are separate from account
quota percentages and do not establish a billed dollar amount.

Automatic checks run at most every five minutes and independently of quota
collection. A manual refresh bypasses that interval. Local and remote scans have
bounded subprocess output and timeouts. A failed token scan cannot replace
successful quota readings.

Agents can use `--agent tokens` after both local agent access and token history
are enabled. See [AGENT_INTEGRATION.md](AGENT_INTEGRATION.md). Never post private
token activity to public issues or attach it to a public release.
