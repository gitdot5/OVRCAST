#!/usr/bin/env python3
"""OVRCAST collector: reads this Mac's AI usage limits and saves a private snapshot.

Runs every 3 minutes from a LaunchAgent in the desktop session, the only place
Claude Code can read its own login. It runs the bundled OVRCAST collector and also reads the
latest limit numbers Codex writes into its session logs (used when the collector's
Codex reading fails). It saves only percentages, reset times, credits and
account emails, and refuses to write anything that looks like a credential.

Standalone on purpose: this one file is copied to every Mac (Python 3.9+).
"""
from __future__ import annotations

import glob
import json
import os
import re
import selectors
import shutil
import subprocess
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

VERSION = "2"
OUT = os.path.expanduser("~/Library/Application Support/UsageBoard/snapshot.json")
BIN_DIR = os.path.expanduser("~/Library/Application Support/UsageBoard/bin")
SESSIONS = os.path.expanduser("~/.codex/sessions")
CODEXBAR_TIMEOUT = 150
TAIL_BYTES = 512 * 1024

SECRET_PATTERNS = [
    re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),  # JWT
    re.compile(r"sk-ant-[A-Za-z0-9_-]{8,}"),
    re.compile(r"\bsk-[A-Za-z0-9]{20,}"),
    re.compile(r"Bearer\s+[A-Za-z0-9._-]{20,}"),
    re.compile(r'"(access_token|refresh_token|id_token|sessionKey|cookie|cookieHeader|apiKey)"\s*:', re.I),
]


def find_secret(text: str) -> bool:
    return any(p.search(text) for p in SECRET_PATTERNS)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_snapshot(stdout: str, rc, codex_logs, now: datetime) -> dict:
    if codex_logs is not None and find_secret(json.dumps(codex_logs)):
        codex_logs = None
    snap = {
        "collector_version": VERSION,
        "collected_at": iso(now),
        "codexbar": {"rc": rc, "rows": [], "error": None},
        "codex_logs": codex_logs,
    }
    if find_secret(stdout):
        snap["codexbar"]["error"] = "refused: OVRCAST collector output looked like it held a credential"
        return snap
    try:
        rows = json.loads(stdout)
        if not isinstance(rows, list):
            raise ValueError("not a list")
    except ValueError:
        snap["codexbar"]["error"] = "OVRCAST collector output unreadable (exit code %s)" % rc
        return snap
    snap["codexbar"]["rows"] = rows
    return snap


def _last_usage_line(path: str):
    with open(path, "rb") as fh:
        fh.seek(0, os.SEEK_END)
        size = fh.tell()
        fh.seek(max(0, size - TAIL_BYTES))
        tail = fh.read().decode("utf-8", errors="ignore")
    for line in reversed(tail.splitlines()):
        if '"token_count"' in line and '"rate_limits"' in line:
            try:
                return json.loads(line)
            except ValueError:
                continue
    return None


def latest_codex_rate_limits(root: str, now: datetime, days: int = 3):
    """Newest Codex usage line from the session logs: limits only, never content."""
    files = []
    for back in range(days):
        day = (now - timedelta(days=back)).strftime("%Y/%m/%d")
        files += glob.glob(os.path.join(root, day, "*.jsonl"))
    files.sort(key=lambda f: os.path.getmtime(f), reverse=True)
    for path in files[:5]:
        event = _last_usage_line(path)
        rl = ((event or {}).get("payload") or {}).get("rate_limits")
        if rl:
            return {"observed_at": event.get("timestamp"), "rate_limits": rl}
    return None


def write_atomic(path: str, data) -> None:
    d = os.path.dirname(path)
    os.makedirs(d, mode=0o700, exist_ok=True)
    os.chmod(d, 0o700)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".snapshot.")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


def _claude_on_path(env: dict) -> None:
    """Studio: point `claude` at the newest Claude Code bundled with the desktop app."""
    pattern = env.get("USAGEBOARD_CLAUDE_GLOB")
    if not pattern:
        return
    matches = sorted(glob.glob(os.path.expanduser(pattern)), key=os.path.getmtime)
    if not matches:
        return
    os.makedirs(BIN_DIR, mode=0o700, exist_ok=True)
    link = os.path.join(BIN_DIR, "claude")
    tmp = link + ".new"
    if os.path.lexists(tmp):
        os.remove(tmp)
    os.symlink(matches[-1], tmp)
    os.replace(tmp, link)
    env["PATH"] = BIN_DIR + os.pathsep + env.get("PATH", "")


def enabled_providers(text: str) -> list:
    try:
        items = json.loads(text)
    except ValueError:
        return []
    return [i["provider"] for i in items if isinstance(i, dict) and i.get("enabled") and i.get("provider")]


def merge_provider_outputs(results: dict) -> list:
    """One bundled collector run per provider -> rows; a slow or bad provider never costs the others."""
    rows = []
    for provider, (stdout, rc) in results.items():
        problem = None
        if rc == "timeout":
            problem = "OVRCAST collector timed out after %d s" % CODEXBAR_TIMEOUT
        elif find_secret(stdout or ""):
            problem = "refused: OVRCAST collector output looked like it held a credential"
        else:
            try:
                got = json.loads(stdout)
                if not isinstance(got, list):
                    raise ValueError("not a list")
                rows += [r for r in got if isinstance(r, dict)]
            except ValueError:
                problem = "OVRCAST collector output unreadable (exit code %s)" % rc
        if problem:
            rows.append({"provider": provider, "source": "collector", "error": {"message": problem}})
    return rows


def _codexbar(exe, args, env):
    try:
        p = subprocess.run([exe] + args, capture_output=True, text=True, timeout=CODEXBAR_TIMEOUT, env=env)
        return p.stdout, p.returncode
    except subprocess.TimeoutExpired:
        return "", "timeout"


def claude_auth_status(env):
    exe = shutil.which("claude", path=env.get("PATH"))
    if not exe:
        return None
    try:
        p = subprocess.run([exe, "auth", "status"], env=env, capture_output=True, text=True, timeout=20)
        status = json.loads(p.stdout)
        return {k: status[k] for k in ("loggedIn", "email", "authMethod")
                if isinstance(status.get(k), (str, bool))}
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def provider_usage(exe, provider, env):
    if provider == "claude" and env.get("USAGEBOARD_CLAUDE_AUTH_CHECK") == "1":
        auth = claude_auth_status(env)
        if auth and auth.get("loggedIn") is False:
            return json.dumps([{"provider": "claude", "source": "cli", "error": {
                "kind": "authentication", "message": "Claude usage sign-in required. Open Reconnect Claude on this Mac and sign in to the account listed on the board."}}]), 1
    args = ["usage", "--provider", provider, "--format", "json", "--no-color"]
    if provider in ("codex", "claude"):
        args += ["--source", "cli" if provider == "codex" else "oauth"]
    return _codexbar(exe, args, env)


def collector_executable(env):
    """Resolve only OVRCAST-owned helpers; never fall back to an external CLI."""
    override = env.get("OVRCAST_COLLECTOR_PATH")
    if override:
        candidates = [override]
    else:
        candidates = ["/Applications/OVRCAST.app/Contents/Helpers/OVRCASTCollector",
                      os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                   "dist/OVRCAST.app/Contents/Helpers/OVRCASTCollector")]
    return next((p for p in candidates if os.path.isfile(p) and os.access(p, os.X_OK)), None)


def run_codexbar():
    # Keep the function and snapshot key for existing fleet/schema compatibility.
    env = dict(os.environ)
    _claude_on_path(env)
    exe = collector_executable(env)
    if not exe:
        return "", "ovrcast-collector-not-found"
    providers = ("codex", "claude", "antigravity")
    with ThreadPoolExecutor(max_workers=len(providers)) as pool:
        futures = {p: pool.submit(provider_usage, exe, p, env) for p in providers}
        results = {p: f.result() for p, f in futures.items()}
    return json.dumps(merge_provider_outputs(results)), 0


def requested_auth_check():
    """One-shot public auth status in the collector's GUI login session.

    Runs Claude's own auth-status command, never reads credential files, and
    keeps only account identity and sign-in state. No sign-in is initiated.
    """
    folder = os.path.dirname(OUT)
    request = os.path.join(folder, "auth-check.request")
    if not os.path.exists(request):
        return
    os.unlink(request)
    env = dict(os.environ)
    _claude_on_path(env)
    paths = [shutil.which("claude", path=env.get("PATH"))]
    bundled = glob.glob(os.path.expanduser("~/Library/Application Support/Claude/claude-code/*/*/claude.app/Contents/MacOS/claude"))
    if bundled:
        paths.append(max(bundled, key=os.path.getmtime))
    results = []
    for exe in dict.fromkeys(p for p in paths if p):
        result = {"executable": exe, "profile": env.get("CLAUDE_CONFIG_DIR") or "default"}
        try:
            p = subprocess.run([exe, "auth", "status"], env=env, capture_output=True, text=True, timeout=20)
            status = json.loads(p.stdout)
            result.update({k: status[k] for k in ("loggedIn", "authMethod", "email", "subscriptionType")
                           if isinstance(status.get(k), (str, bool))})
            result["exit_code"] = p.returncode
        except (OSError, ValueError, subprocess.TimeoutExpired):
            result["error"] = "Auth status unavailable in the GUI collector session"
        results.append(result)
    write_atomic(os.path.join(folder, "auth-check.json"), {"checked_at": iso(datetime.now(timezone.utc)), "results": results})


def codex_account_usage(timeout=30):
    """Read usage through Codex's own protocol; never read auth files or start a turn."""
    exe = shutil.which("codex")
    if not exe:
        return None
    proc = subprocess.Popen([exe, "app-server", "--stdio"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    pending, buffer = {}, b""
    deadline = time.monotonic() + timeout

    def send(message):
        proc.stdin.write((json.dumps(message) + "\n").encode())
        proc.stdin.flush()

    try:
        send({"id": 1, "method": "initialize", "params": {
            "clientInfo": {"name": "usage_board", "version": VERSION},
            "capabilities": {"experimentalApi": True}}})
        while time.monotonic() < deadline:
            if not selector.select(max(0, deadline - time.monotonic())):
                break
            chunk = os.read(proc.stdout.fileno(), 65536)
            if not chunk:
                break
            buffer += chunk
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                try:
                    message = json.loads(line)
                except ValueError:
                    continue
                mid = message.get("id")
                if mid == 1:
                    if "error" in message:
                        return None
                    send({"method": "initialized"})
                    send({"id": 2, "method": "account/read", "params": {"refreshToken": False}})
                    send({"id": 3, "method": "account/rateLimits/read", "params": None})
                elif mid in (2, 3):
                    pending[mid] = message.get("result") or {}
            if 2 in pending and 3 in pending:
                account = pending[2].get("account") or {}
                usage = pending[3]
                if not account.get("email") or not usage.get("rateLimits"):
                    return None
                result = {"email": account["email"], "observed_at": iso(datetime.now(timezone.utc)),
                          "rateLimits": usage["rateLimits"],
                          "rateLimitsByLimitId": usage.get("rateLimitsByLimitId"),
                          "rateLimitResetCredits": usage.get("rateLimitResetCredits")}
                inventory = result.get("rateLimitResetCredits")
                if isinstance(inventory, dict) and isinstance(inventory.get("credits"), list):
                    inventory["credits"] = [{k: c[k] for k in ("expiresAt", "resetType", "status", "title") if k in c}
                                            for c in inventory["credits"] if isinstance(c, dict)]
                return None if find_secret(json.dumps(result)) else result
    except (OSError, ValueError, BrokenPipeError):
        return None
    finally:
        selector.close()
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    return None


def main() -> None:
    requested_auth_check()
    now = datetime.now(timezone.utc)
    with ThreadPoolExecutor(max_workers=2) as pool:
        live = pool.submit(codex_account_usage)
        stdout, rc = run_codexbar()
        codex_usage = live.result()
    logs = latest_codex_rate_limits(SESSIONS, now)
    snapshot = build_snapshot(stdout, rc, logs, now)
    snapshot["codex_account"] = codex_usage
    write_atomic(OUT, snapshot)


if __name__ == "__main__":
    main()
