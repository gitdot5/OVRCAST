#!/usr/bin/env python3
"""OVRCAST gatherer (MacBook): pulls every Mac's snapshot and writes the board.

Remote Macs are read with one read-only `cat` over the existing Tailscale SSH
setup (pinned host keys, BatchMode, no forwarding). Nothing listens on a port and
nothing is published. Run with no arguments to refresh and print the board;
--quiet (used by the LaunchAgent) refreshes without printing; --open also opens
the page.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import fcntl
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)

import board  # noqa: E402
import native_snapshot  # noqa: E402
from collect import find_secret, write_atomic  # noqa: E402

CONFIG_PATH = os.path.join(ROOT, "config.local.json")
if not os.path.isfile(CONFIG_PATH):
    CONFIG_PATH = os.path.join(ROOT, "config.json")
STATE_DIR = os.path.join(ROOT, "state")
REMOTE_CMD = 'cat "$HOME/Library/Application Support/UsageBoard/snapshot.json"'
SSH_TIMEOUT = 40


def request_collection(config):
    """Kick only the existing usage collectors; no provider settings are changed."""
    def request(mcfg):
        if mcfg.get("local_path"):
            args = ["/bin/launchctl", "kickstart", "gui/%d/com.weekthink.usageboard.collect" % os.getuid()]
        else:
            args = ["/usr/bin/ssh", "-o", "ClearAllForwardings=yes"] + list(mcfg["ssh"]) + [
                'launchctl kickstart gui/$(id -u)/com.weekthink.usageboard.collect']
        try:
            return subprocess.run(args, capture_output=True, timeout=SSH_TIMEOUT, stdin=subprocess.DEVNULL).returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False
    with ThreadPoolExecutor(max_workers=3) as pool:
        return list(pool.map(request, (config.get("machines") or {}).values()))


def fetch(mcfg):
    """Return (text, error) for one machine's snapshot."""
    if mcfg.get("local_path"):
        path = os.path.expanduser(mcfg["local_path"])
        try:
            with open(path) as fh:
                return fh.read(), None
        except OSError:
            return None, "no snapshot file yet"
    argv = ["/usr/bin/ssh", "-o", "ClearAllForwardings=yes"] + list(mcfg["ssh"]) + [REMOTE_CMD]
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=SSH_TIMEOUT, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        return None, "ssh timed out"
    if p.returncode != 0:
        last = (p.stderr.strip().splitlines() or ["exit %d" % p.returncode])[-1]
        return None, "ssh failed: " + last[:160]
    return p.stdout, None


def merge_fetch(previous, text, error, now):
    previous = previous or {"snapshot": None, "last_ok_at": None}
    if error is None:
        if find_secret(text or ""):
            error = "refused: snapshot looked like it held a credential"
        else:
            try:
                snap = json.loads(text)
                if not isinstance(snap, dict):
                    raise ValueError("not an object")
                return {"snapshot": snap, "fetch_error": None, "last_ok_at": board.iso(now)}
            except ValueError:
                error = "snapshot unreadable"
    return {"snapshot": previous.get("snapshot"), "fetch_error": error, "last_ok_at": previous.get("last_ok_at")}


def _load(path, default):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def run(now=None, verbose=True, open_page=False, config_path=CONFIG_PATH, state_dir=STATE_DIR, out_dir=ROOT):
    now = now or datetime.now(timezone.utc)
    config = _load(config_path, {})
    state = _load(os.path.join(state_dir, "machines.json"), {})
    history = _load(os.path.join(state_dir, "history.json"), {})
    last_good = _load(os.path.join(state_dir, "last_good.json"), {})
    machines = {}
    items = list((config.get("machines") or {}).items())
    with ThreadPoolExecutor(max_workers=3) as pool:
        fetched = list(pool.map(lambda pair: fetch(pair[1]), items))
    for (name, _), (text, err) in zip(items, fetched):
        machines[name] = merge_fetch(state.get(name), text, err, now)
    accounts = board.build_accounts(machines, config, now)
    accounts = board.carry_forward(accounts, last_good, now)
    board.update_history(history, accounts, now)
    board.attach_forecasts(accounts, history, now)
    write_atomic(os.path.join(state_dir, "machines.json"), machines)
    write_atomic(os.path.join(state_dir, "history.json"), history)
    write_atomic(os.path.join(state_dir, "last_good.json"), last_good)
    write_atomic(os.path.join(state_dir, "overview.json"), native_snapshot.build(accounts, now))
    page = os.path.join(out_dir, "board.html")
    _write_text(page, board.render_html(accounts, config, now))
    text = board.render_text(accounts, config, now)
    _write_text(os.path.join(out_dir, "board.txt"), text)
    if verbose:
        print(text)
    if open_page:
        subprocess.run(["/usr/bin/open", page])


def _write_text(path, text):
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(text)
    os.replace(tmp, path)


if __name__ == "__main__":
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    fd = os.open(os.path.join(STATE_DIR, "gather.lock"), os.O_CREAT | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            sys.exit(0)
        if "--refresh" in sys.argv:
            request_collection(_load(CONFIG_PATH, {}))
        run(verbose="--quiet" not in sys.argv, open_page="--open" in sys.argv)
