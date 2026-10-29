# OVRCAST-maintained collector

This is a source fork of CodexBar v0.81.0, pinned to the revision recorded in
UPSTREAM.json. The original MIT license and upstream copyright remain intact.
OVRCAST maintains this copy; installed apps do not contact CodexBar for updates
or require a CodexBar installation. There are no remote Swift package dependencies.

The source subset retains CodexBarCore, CodexBarCLI, CQuickJS and CSQLite3.
Commander, SweetCookieKit and swift-log source subsets are also retained locally
at exact revisions in DEPENDENCIES.json, together with their original licenses.
Documentation build plugins and unrelated app/updater targets are excluded.
macOS supplies CryptoKit; the fork uses it instead of building swift-crypto.

The executable is OVRCASTCollector. Its entrypoint permits usage, config providers,
help/version and the deterministic resource smoke probe. Upstream server,
configuration mutation, session focus, hooks and reset/purchase actions are not
available through this executable. The GUI invokes read-only usage commands. Local user provider plugins are not activated.
Internal module/type and JSON schema names remain unchanged for compatibility.

Application-owned defaults, configuration and cache namespaces are changed to
OVRCAST. The default collector config is .config/ovrcast/config.json (or its
XDG_CONFIG_HOME equivalent); OVRCAST_COLLECTOR_CONFIG is the explicit override.
Provider-owned Codex, Claude Code and Antigravity sign-in locations are retained.
Existing CodexBar-specific token configuration is not silently copied. Users
connect through provider software; provider authentication remains required.

FILE_MANIFEST.sha256 is an explicit integrity allowlist for source exports.
Build outputs, checkouts, user configuration, credentials and private state are
never included. Refresh the manifest only after reviewing intentional fork edits.
The exported source includes all local package dependencies for offline builds.
