#!/usr/bin/env python3
"""Install (or reinstall) a OVRCAST LaunchAgent for the current user on this Mac.

  install_agent.py collect                    collector, normal Claude Code login
  install_agent.py collect --isolated-claude  collector reading a separate Claude login
                                              (~/.claude-usageboard) via the desktop app's
                                              bundled Claude Code (Studio)
  install_agent.py gather <path/to/gather.py> gatherer (MacBook only)

The job runs in the desktop session (gui/<uid>), every 3 minutes, at low priority.
"""
import os
import plistlib
import subprocess
import sys

HOME = os.path.expanduser("~")
UB = os.path.join(HOME, "Library", "Application Support", "UsageBoard")
LOGS = os.path.join(HOME, "Library", "Logs", "UsageBoard")
PATH = ":".join([os.path.join(HOME, ".local", "bin"), "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"])


def agent(label, program, env):
    return {
        "Label": label,
        "ProgramArguments": ["/usr/bin/python3", "-I", program] + (["--quiet"] if label.endswith("gather") else []),
        "StartInterval": 180,
        "RunAtLoad": True,
        "ProcessType": "Background",
        "LowPriorityIO": True,
        "Nice": 10,
        "EnvironmentVariables": dict({"PATH": PATH, "HOME": HOME}, **env),
        "StandardOutPath": os.path.join(LOGS, label.rsplit(".", 1)[1] + ".log"),
        "StandardErrorPath": os.path.join(LOGS, label.rsplit(".", 1)[1] + ".log"),
    }


def main():
    kind = sys.argv[1]
    os.makedirs(UB, mode=0o700, exist_ok=True)
    os.makedirs(LOGS, mode=0o700, exist_ok=True)
    env = {}
    if kind == "collect":
        label, program = "com.weekthink.usageboard.collect", os.path.join(UB, "collect.py")
        if "--isolated-claude" in sys.argv:
            env = {"CLAUDE_CONFIG_DIR": os.path.join(HOME, ".claude-usageboard"),
                   "CODEXBAR_CONFIG": os.path.join(UB, "codexbar-config.json"),
                   "USAGEBOARD_CLAUDE_GLOB": os.path.join(
                       HOME, "Library", "Application Support", "Claude", "claude-code",
                       "*", "*", "claude.app", "Contents", "MacOS", "claude")}
    elif kind == "gather":
        label, program = "com.weekthink.usageboard.gather", os.path.abspath(sys.argv[2])
    else:
        sys.exit("unknown agent: " + kind)
    if not os.path.isfile(program):
        sys.exit("missing " + program)
    path = os.path.join(HOME, "Library", "LaunchAgents", label + ".plist")
    with open(path, "wb") as fh:
        plistlib.dump(agent(label, program, env), fh)
    domain = "gui/%d" % os.getuid()
    subprocess.run(["/bin/launchctl", "bootout", domain + "/" + label], capture_output=True)
    r = subprocess.run(["/bin/launchctl", "bootstrap", domain, path], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("launchctl bootstrap failed: " + (r.stderr.strip() or str(r.returncode)))
    print("installed", label, "->", path)


if __name__ == "__main__":
    main()
