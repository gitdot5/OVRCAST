# Configuration and troubleshooting

## Native app

For the 0.3 app, start in Settings → Connect. It uses CodexBar directly and
keeps preferences, seven-day history and snapshots in
`~/Library/Application Support/UsageBoard/App/` as owner-only files.
The app polls every three minutes while running and rereads display state every
15 seconds. No background agent is installed by the native setup.

A remote Mac must run OVRCAST and have an existing, trusted SSH alias.
Settings → Computers reads its `native-overview.json` file through that alias.
Offline computers retain cached readings with an unavailable state.

Connection help opens the provider app or the existing isolated-profile
reconnect helper on the affected local Mac. A remote sign-in must be completed
on that computer. Opening a provider app is not proof of a successful sign-in.

The sections below describe optional legacy scripted collection.

## Legacy collection

`gather.py` uses `config.local.json` when present and otherwise uses `config.json`.
Keep personal configuration in the ignored local file. Relative snapshot data
is written under `state/`; the generated overview is `board.html` and `board.txt`.

## Account labels

The optional `expected`, `plans` and `also_used_by` fields use this form:

```json
{
  "timezone": "UTC",
  "machines": {
    "MacBook": {
      "local_path": "~/Library/Application Support/UsageBoard/snapshot.json"
    }
  },
  "expected": {"MacBook": {"Claude": "you@example.com"}},
  "plans": {"claude:you@example.com": "Your plan label"},
  "also_used_by": {}
}
```

Provider names in `expected` are `Codex`, `Claude` and `Antigravity`. Account
keys in `plans` use a lowercase provider and lowercase email. Account labels
do not authenticate or change the account used by a provider tool.

## More Macs

On each additional Mac, install/configure your own CodexBar CLI, copy `collect.py`
to `~/Library/Application Support/UsageBoard/collect.py`, run it, and optionally
install its collector agent. Do not copy account credentials between Macs.

Set up SSH yourself with host-key verification, a trusted identity, BatchMode
and no forwarding. Then add an entry such as this to `machines`:

```json
"Mini": {
  "ssh": ["-o", "BatchMode=yes", "-o", "ConnectTimeout=15",
          "-o", "StrictHostKeyChecking=yes", "your-configured-ssh-alias"]
}
```

The gatherer reads the remote snapshot through SSH. Refresh requests kickstart
the existing usage collector there. The app does not provision SSH, trust a new
host key, install a remote agent, or open a network port. Machine filters accept
your configured names; `MacBook`, `Mini` and `Studio` get standard ordering.

## Claude shows no reading

Check the configured Claude source in CodexBar and verify Claude's own sign-in
status in the same desktop session and profile used by the collector. A terminal
SSH session can differ from the logged-in GUI session. Never paste tokens into
OVRCAST or an issue report.

If you need separation from an existing Claude worker, explicitly create and
authenticate your own separate usage profile first. The collector installer
supports `install_agent.py collect --isolated-claude`, which selects
`~/.claude-usageboard` and the Claude desktop app's bundled CLI. It also points
CodexBar at `~/Library/Application Support/UsageBoard/codexbar-config.json`;
you must supply that configuration using CodexBar's own supported configuration
workflow. It does not create a sign-in or copy credentials automatically.

Some sources omit saved resets, cloud-session credits or API balances. These
remain unknown even when percentage allowances are available. Paid/API pools
and subscription allowances are distinct and are never added together.

## Remove background collection

Run the following only for the OVRCAST jobs you installed:

```sh
launchctl bootout "gui/$(id -u)/com.weekthink.usageboard.collect"
launchctl bootout "gui/$(id -u)/com.weekthink.usageboard.gather"
rm -f "$HOME/Library/LaunchAgents/com.weekthink.usageboard.collect.plist"
rm -f "$HOME/Library/LaunchAgents/com.weekthink.usageboard.gather.plist"
```

Quit OVRCAST and remove its app bundle if desired. Local configuration,
snapshots and logs remain until you delete them. Provider apps, logins and SSH
configuration belong to you and are not removed by these commands.
