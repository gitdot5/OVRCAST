# Local agent access

OVRCAST can give local coding agents a credential-free view of capacity across
providers and Macs. Enable **Settings → Connect → Local agents → Allow agents to
read capacity**. Access starts off and is checked on every command. Turning it
off immediately disables subsequent commands. No HTTP listener, remote MCP
service, credentials or automatic execution is introduced.

Use the executable inside the installed app. These commands exit without opening
the GUI, collecting provider data, refreshing credentials or changing files:

```sh
OVRCAST="/Applications/OVRCAST.app/Contents/MacOS/UsageBoardMenuBar"
"$OVRCAST" --agent status
"$OVRCAST" --agent tokens --provider Claude
"$OVRCAST" --agent recommend --provider Claude --minimum-remaining 20
"$OVRCAST" --agent recommend --provider Codex --machine mac-1
```

Build 13 or newer is required. The public 0.4.3 app does not include this interface.
The GUI must already have collected a valid saved reading. Commands read the same
native or existing-collector snapshot selected by the app; they never fall back
to a different data source when it fails.

`tokens` additionally requires Token history to be enabled. It reads the saved
counter ledger independently of quota status and reports Today and Last 7 days
for each harness and Mac, including partial/unknown states. No fleet total is
created. See [TOKEN_ACTIVITY.md](TOKEN_ACTIVITY.md). Machine references are scoped
to the particular response and are not interchangeable between different reports.

## Contract

The only output is schema-versioned JSON. `status` reports anonymous account and
machine references, provider, observation time, state, quota percentages, reset
times and eligibility. Account identities, custom names, plans, raw errors, credit
balances, tokens, SSH aliases and provider-supplied free text are excluded.

`account-N`, `mac-N` and `window-N` are references within a snapshot. They can
change when its membership changes. Correlate a recommendation with its returned
snapshot and observation time; never persist an ID as an account identity or
execution route. Machine families are descriptive, and reachability is explicitly
unknown. Machine associations do not prove that a harness is installed or signed
in on that computer. A quota shared by an account is counted once, regardless of
how many machines use it.

`recommend` gives one capacity option per matching provider. It applies every
reported window and uses the lowest remaining percentage. It excludes stale or
future-dated readings, expired reset windows, sign-in problems, connection issues,
unknown or exhausted quotas, retired-only machines and capacity below the given
threshold. The default threshold is 15%. A missing reset time stays unknown.
Readings older than ten minutes require a refresh in the app.

These are capacity options for an agent's task and cost review. Percentages from
different providers are not comparable dollar costs, and quota is not a token or
task-size estimate. Model suitability, task size, verified machine/harness
availability and actual plan or marginal pricing are separate inputs. The command
does not pick a cheapest cross-provider harness or claim savings without those
inputs. `costDataAvailable` and `automaticExecution` are both false.

Agents may use this information to suggest existing included capacity before
considering paid work. OVRCAST cannot launch jobs, change billing or accounts,
dispatch SSH commands, reserve capacity or synchronize concurrent agents. Another
job can consume quota after the reading; recheck before making a routing decision.
Do not attach the output to public issues or transmit it to a service without the
user's authorization. The output is redacted usage data, not a public support report.

Exit codes:

| Code | Meaning |
| --- | --- |
| 0 | Status read, or capacity options returned. Inspect states and timestamps. |
| 2 | No eligible capacity. Wait, refresh or ask for a decision; do not spend automatically. |
| 64 | Invalid command, option or machine reference. |
| 65 | Invalid saved snapshot. |
| 66 | No saved snapshot. |
| 77 | Local agent access is disabled or preferences cannot be read. |

`--agent --help` works without enabling access. Unsupported options and failures
return static errors without echoing untrusted input or private paths.
