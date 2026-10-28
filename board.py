"""OVRCAST: turns each Mac's collector snapshot into one view of every AI plan's limits.

Limits belong to accounts, not machines, so readings are merged into one row per
(tool, account) that lists every Mac using it. Pure functions only: gather.py
does the fetching and file writing.
"""
from __future__ import annotations

import math
import capacity
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

UTC = timezone.utc
STALE_AFTER = timedelta(minutes=10)
HISTORY_KEEP = timedelta(hours=26)
FORECAST_LOOKBACK = timedelta(minutes=90)
FORECAST_MIN_SPAN = timedelta(minutes=20)

TOOLS = {"codex": "Codex", "claude": "Claude", "antigravity": "Antigravity", "gemini": "Gemini",
         "claudeplatform": "Claude Platform", "claude-platform": "Claude Platform"}
PLAN_NAMES = {"pro": "Pro", "promax": "Pro (top tier)", "prolite": "Pro Lite", "plus": "Plus", "max": "Max"}
FRIENDLY_ERRORS = [
    ("No available fetch strategy for claude",
     "Claude Code can't read its login on this Mac (not signed in yet, or its Keychain is locked)."),
    ("timed out waiting for `initialize`", "Codex was too slow to start on this Mac."),
]


# ---------- parsing ----------

def parse_time(s):
    if not s:
        return None
    try:
        if isinstance(s, (int, float)) and not isinstance(s, bool):
            return datetime.fromtimestamp(s, UTC)
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        return dt if dt.tzinfo else dt.replace(tzinfo=UTC)
    except (ValueError, TypeError, AttributeError, OverflowError, OSError):
        return None


def iso(dt):
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def _label(minutes, given=None):
    if minutes == 300:
        return "5-hour"
    if given:
        return given
    return "Weekly" if minutes == 10080 else "%d-hour" % ((minutes or 0) // 60)


def _window(used, minutes, resets, label, now):
    if isinstance(used, bool) or not isinstance(used, (int, float)) or not math.isfinite(used) or not 0 <= used <= 100:
        return None
    resets_at = parse_time(resets)
    return {"label": label, "used": int(round(used)), "minutes": minutes, "resets_at": resets_at,
            "reset_passed": bool(resets_at and resets_at <= now)}


def _split(main, extras):
    """Pick the 5-hour and the most-used weekly window; the rest become 'others'."""
    five = next((w for w in main if w["minutes"] == 300), None)
    weeklies = [w for w in main if w["minutes"] == 10080]
    weekly = max(weeklies, key=lambda w: w["used"]) if weeklies else None
    others = [w for w in main if w is not five and w is not weekly]
    seen = {(w["used"], w["resets_at"], w["minutes"]) for w in main}
    others += [w for w in extras if (w["used"], w["resets_at"], w["minutes"]) not in seen]
    return five, weekly, others


def windows_from_codexbar(usage, labels, now):
    labels = labels or {}
    main = []
    for k in ("primary", "secondary", "tertiary"):
        w = usage.get(k)
        if w:
            win = _window(w.get("usedPercent"), w.get("windowMinutes"), w.get("resetsAt"),
                          _label(w.get("windowMinutes"), labels.get(k)), now)
            if win:
                main.append(win)
    extras = []
    for e in usage.get("extraRateWindows") or []:
        if e.get("usageKnown") is False:
            continue
        w = e.get("window") or {}
        win = _window(w.get("usedPercent"), w.get("windowMinutes"), w.get("resetsAt"),
                      e.get("title") or _label(w.get("windowMinutes")), now)
        if win:
            extras.append(win)
    return _split(main, extras)


def windows_from_logs(rate_limits, now):
    main = []
    for k in ("primary", "secondary"):
        w = rate_limits.get(k)
        if w:
            win = _window(w.get("used_percent"), w.get("window_minutes"), w.get("resets_at"),
                          _label(w.get("window_minutes")), now)
            if win:
                main.append(win)
    return _split(main, [])


# ---------- accounts ----------

def _friendly(message):
    for needle, text in FRIENDLY_ERRORS:
        if needle in (message or ""):
            return text
    return message or "No reading."


def _plan(config, key, login_method):
    if key in (config.get("plans") or {}):
        return config["plans"][key]
    if login_method and login_method.lower() != "unknown":
        return PLAN_NAMES.get(login_method.lower(), login_method)
    return None


def _entry(machine, tool, email, config, **fields):
    expected = ((config.get("expected") or {}).get(machine) or {}).get(tool)
    email = email or expected
    key = "%s:%s" % (tool.lower(), email.lower() if email else "@" + machine)
    note = None
    if expected and email and email.lower() != expected.lower():
        note = "Expected %s on %s" % (expected, machine)
    base = {"key": key, "tool": tool, "email": email, "machine": machine, "five_hour": None, "weekly": None,
            "others": [], "credits": None, "source": None, "observed_at": None, "error": None, "note": note,
            "plan_hint": None}
    base.update(fields)
    return base


def _entries_for_machine(name, m, config, now):
    snap = m.get("snapshot")
    expected = (config.get("expected") or {}).get(name) or {}
    if not snap:
        why = "No reading from %s yet%s." % (name, " (%s)" % m["fetch_error"] if m.get("fetch_error") else "")
        return [_entry(name, tool, None, config, error=why) for tool in expected]
    collected = parse_time(snap.get("collected_at"))
    rows = (snap.get("codexbar") or {}).get("rows") or []
    out, codex_error, codex_ok = [], None, False
    for r in rows:
        tool = TOOLS.get(r.get("provider"), (r.get("provider") or "?").title())
        if r.get("error"):
            if tool == "Codex":
                codex_error = r["error"].get("message")
            else:
                out.append(_entry(name, tool, None, config, error=_friendly(r["error"].get("message")),
                                  requires_sign_in=r["error"].get("kind") == "authentication",
                                  observed_at=collected))
            continue
        usage = r.get("usage") or {}
        if r.get("source") == "offline":
            out.append(_entry(name, tool, None, config, observed_at=collected,
                              error="%s is not running, so there's no live reading." % tool))
            continue
        ident = usage.get("identity") or {}
        five, weekly, others = windows_from_codexbar(usage, r.get("rateWindowLabels"), now)
        extra = capacity.normalize(r)
        credits = extra["balance"]
        out.append(_entry(name, tool, ident.get("accountEmail") or usage.get("accountEmail"), config,
                          five_hour=five, weekly=weekly, others=others, source="CodexBar",
                          credits=float(credits) if credits is not None else None,
                          capacity=extra, reading_source=r.get("source"),
                          observed_at=parse_time(usage.get("updatedAt")) or collected,
                          plan_hint=ident.get("loginMethod") or usage.get("loginMethod")))
        codex_ok = codex_ok or tool == "Codex"
    live = snap.get("codex_account")
    if live and live.get("email") and live.get("rateLimits"):
        rl = live["rateLimits"]
        windows = []
        for label in ("primary", "secondary"):
            w = rl.get(label) or {}
            win = _window(w.get("usedPercent"), w.get("windowDurationMins"), w.get("resetsAt"),
                          _label(w.get("windowDurationMins")), now)
            if win:
                windows.append(win)
        five, weekly, others = _split(windows, [])
        extra = capacity.normalize({"usage": {"codexResetCredits": live.get("rateLimitResetCredits")},
                                    "credits": {"remaining": (rl.get("credits") or {}).get("balance")}})
        inventory = live.get("rateLimitResetCredits") or {}
        extra["resets"]["inventory"] = [{k: c[k] for k in ("expiresAt", "resetType", "status", "title") if k in c}
                                          for c in inventory.get("credits") or []]
        out = [e for e in out if not (e["tool"] == "Codex" and
               (not e["email"] or e["email"].lower() == live["email"].lower()))]
        out.append(_entry(name, "Codex", live["email"], config, five_hour=five, weekly=weekly,
                          others=others, credits=extra["balance"], capacity=extra, source="Codex app server",
                          observed_at=parse_time(live["observed_at"]), plan_hint=rl.get("planType")))
        codex_ok = True
    logs = snap.get("codex_logs")
    if not codex_ok and logs and logs.get("rate_limits"):
        rl = logs["rate_limits"]
        five, weekly, others = windows_from_logs(rl, now)
        bal = (rl.get("credits") or {}).get("balance")
        out.append(_entry(name, "Codex", None, config, five_hour=five, weekly=weekly, others=others,
                          source="Codex logs", credits=float(bal) if bal is not None else None,
                          observed_at=parse_time(logs.get("observed_at")), plan_hint=rl.get("plan_type")))
    elif not codex_ok and codex_error:
        out.append(_entry(name, "Codex", None, config, error=_friendly(codex_error), observed_at=collected))
    reported = {e["tool"] for e in out}
    why = (snap.get("codexbar") or {}).get("error") or "not reported"
    for tool in expected:
        if tool not in reported:
            out.append(_entry(name, tool, None, config, observed_at=collected,
                              error="No reading in the latest check (%s)." % why))
    if m.get("fetch_error"):
        since = parse_time(m.get("last_ok_at"))
        msg = "%s unreachable%s" % (name, " since " + fmt_when(since, now, _tz(config)) if since else "")
        for e in out:
            e["note"] = "; ".join(x for x in (e["note"], msg) if x)
    return out


def build_accounts(machines, config, now):
    entries = []
    for name, m in machines.items():
        entries += _entries_for_machine(name, m, config, now)
    groups = {}
    for e in entries:
        groups.setdefault(e["key"], []).append(e)
    accounts = []
    for key, es in groups.items():
        ok = [e for e in es if not e["error"]]
        pool = ok or es
        best = max(pool, key=lambda e: e["observed_at"] or datetime.min.replace(tzinfo=UTC))
        machines_list = []
        for e in es:
            if e["machine"] not in machines_list:
                machines_list.append(e["machine"])
        machines_list += (config.get("also_used_by") or {}).get(key, [])
        notes = []
        for e in es:
            if e["note"] and e["note"] not in notes:
                notes.append(e["note"])
        acc = dict(best)
        acc.pop("machine")
        acc["machines"] = machines_list
        acc["note"] = "; ".join(notes) or None
        acc["plan"] = _plan(config, key, acc.pop("plan_hint"))
        acc["stale"] = acc["observed_at"] is None or now - acc["observed_at"] > STALE_AFTER
        acc["forecast"] = None
        accounts.append(acc)
    return accounts


# ---------- last good reading ----------

CARRY_MAX = timedelta(hours=6)
_WINDOW_KEYS = ("five_hour", "weekly")


def _to_state(a):
    def win(w):
        return dict(w, resets_at=iso(w["resets_at"]) if w["resets_at"] else None)
    s = {k: v for k, v in a.items() if k != "forecast"}
    for k in _WINDOW_KEYS:
        s[k] = win(a[k]) if a[k] else None
    s["others"] = [win(w) for w in a["others"]]
    s["observed_at"] = iso(a["observed_at"]) if a["observed_at"] else None
    return s


def _from_state(s, now):
    def win(w):
        r = parse_time(w["resets_at"])
        return dict(w, resets_at=r, reset_passed=bool(r and r <= now))
    a = dict(s)
    for k in _WINDOW_KEYS:
        a[k] = win(s[k]) if s.get(k) else None
    a["others"] = [win(w) for w in s.get("others") or []]
    a["observed_at"] = parse_time(s.get("observed_at"))
    a["stale"] = a["observed_at"] is None or now - a["observed_at"] > STALE_AFTER
    a["forecast"] = None
    return a


def carry_forward(accounts, last_good, now):
    """Keep the newest good reading per account; one failed check never wipes good numbers.

    `last_good` (key -> saved account) is updated in place for the caller to persist.
    """
    out = []
    for a in accounts:
        prev = _from_state(last_good[a["key"]], now) if a["key"] in last_good else None
        if prev and prev["observed_at"] and now - prev["observed_at"] > CARRY_MAX:
            prev = None
        newest_ok = not a["error"] and (prev is None or (a["observed_at"] and a["observed_at"] >= prev["observed_at"]))
        if newest_ok or prev is None:
            if not a["error"]:
                last_good[a["key"]] = _to_state(a)
            out.append(a)
            continue
        keep = dict(prev, machines=a["machines"], last_check_failed=bool(a["error"]), stale=True,
                    requires_sign_in=bool(a.get("requires_sign_in")))
        notes = [n for n in (a["note"], "Latest check failed: " + a["error"] if a["error"] else None) if n]
        keep["note"] = "; ".join(notes) or None
        out.append(keep)
    return out


# ---------- history + forecast ----------

def update_history(history, accounts, now):
    for a in accounts:
        if a["error"] or not a["observed_at"]:
            continue
        for wname in ("five_hour", "weekly"):
            w = a[wname]
            if not w:
                continue
            pts = history.setdefault("%s|%s" % (a["key"], wname), [])
            ts = iso(a["observed_at"])
            if not pts or pts[-1][0] != ts:
                pts.append([ts, w["used"]])
    cutoff = now - HISTORY_KEEP
    for k in list(history):
        history[k] = [p for p in history[k] if parse_time(p[0]) >= cutoff]
        if not history[k]:
            del history[k]
    return history


def forecast(points, used_now, resets_at, now):
    pts = sorted(points)
    start = 0
    for i in range(1, len(pts)):
        if pts[i][1] < pts[i - 1][1]:
            start = i
    pts = [p for p in pts[start:] if p[0] >= now - FORECAST_LOOKBACK]
    if len(pts) < 2:
        return None
    span = pts[-1][0] - pts[0][0]
    if span < FORECAST_MIN_SPAN:
        return None
    rate = (pts[-1][1] - pts[0][1]) / (span.total_seconds() / 3600)
    if rate <= 0:
        return None
    eta = now + timedelta(hours=(100 - used_now) / rate)
    return {"eta": eta, "before_reset": resets_at is not None and eta < resets_at, "rate_per_hour": rate,
            "as_of": now, "span_minutes": int(span.total_seconds() / 60),
            "reliable": pts[-1][1] - pts[0][1] >= 2,
            "confidence": "Moderate" if len(pts) >= 5 and span >= timedelta(hours=1) and pts[-1][1] - pts[0][1] >= 5 else "Low"}


def attach_forecasts(accounts, history, now):
    for a in accounts:
        best = None
        for wname in ("five_hour", "weekly"):
            w = a[wname]
            if a["error"] or a["stale"] or a.get("last_check_failed") or not w or w["reset_passed"]:
                continue
            pts = [(parse_time(ts), used) for ts, used in history.get("%s|%s" % (a["key"], wname), [])]
            f = forecast(pts, w["used"], w["resets_at"], now)
            if f and f["reliable"] and f["before_reset"] and (best is None or f["eta"] < best["eta"]):
                best = dict(f, label=w["label"])
        a["forecast"] = best
    return accounts


# ---------- rendering ----------

def _tz(config):
    return ZoneInfo(config.get("timezone") or "America/New_York")


def fmt_when(dt, now, tz):
    loc, today = dt.astimezone(tz), now.astimezone(tz).date()
    hm = loc.strftime("%I:%M %p").lstrip("0")
    if loc.date() == today:
        return hm + " today"
    if loc.date() == today + timedelta(days=1):
        return hm + " tomorrow"
    return "%s %d/%d %s" % (loc.strftime("%a"), loc.month, loc.day, hm)


def fmt_age(dt, now):
    if not dt:
        return "never"
    mins = int((now - dt).total_seconds() // 60)
    if mins < 1:
        return "just now"
    if mins < 120:
        return "%d min ago" % mins
    return "%d h ago" % (mins // 60)


def status(left):
    if left > 40:
        return "good", "OK"
    if left >= 15:
        return "warning", "Low"
    return "critical", "Very low"


def _min_left(a):
    lefts = [100 - w["used"] for w in all_windows(a) if not w["reset_passed"]]
    return min(lefts) if lefts else None


def all_windows(a):
    return [w for w in [a.get("five_hour"), a.get("weekly")] + a.get("others", []) if w]


def account_status(a):
    if a.get("requires_sign_in"):
        return "unknown", "Sign in required"
    if a.get("error") or a.get("stale") or a.get("last_check_failed"):
        return "unknown", "Reading unavailable"
    windows = all_windows(a)
    if not windows or any(w["reset_passed"] for w in windows):
        return "unknown", "Awaiting current reading"
    exhausted = [w for w in windows if w["used"] >= 100]
    if exhausted:
        core = any(w is a.get("five_hour") or w is a.get("weekly") for w in exhausted)
        return "critical", "Included limit reached" if core else "Model limit reached"
    if a.get("forecast"):
        hours = (a["forecast"]["eta"] - a["forecast"].get("as_of", a["observed_at"])).total_seconds() / 3600
        return ("critical" if hours <= 2 else "warning"), "At risk before reset"
    left = _min_left(a)
    if left is not None and left < 15:
        return "warning", "Limited headroom"
    return "good", "Available"


def ordered(accounts):
    rank = {"critical": 0, "warning": 1, "unknown": 2, "good": 3}
    return sorted(accounts, key=lambda a: (rank[account_status(a)[0]],
                  _min_left(a) if _min_left(a) is not None else -1, a["tool"], a["email"] or ""))


def _window_line(w, now, tz):
    if w["reset_passed"]:
        return "reset at %s, waiting for a new reading" % fmt_when(w["resets_at"], now, tz)
    left = 100 - w["used"]
    text = "%d%% left (%s)" % (left, status(left)[1])
    if w["resets_at"]:
        text += ", resets %s" % fmt_when(w["resets_at"], now, tz)
    return text


def _forecast_line(a, now, tz):
    f = a["forecast"]
    hours = max(0, (f["eta"] - now).total_seconds() / 3600)
    if hours < 1:
        duration = "under 1 hour"
    elif hours < 48:
        duration = "%d–%d hours" % (max(1, math.floor(hours * .75)), max(2, math.ceil(hours * 1.25)))
    else:
        duration = "%d–%d days" % (max(1, math.floor(hours / 24 * .75)), math.ceil(hours / 24 * 1.25))
    return "Runs out in about %s at recent pace (%s). %s confidence; %d min observed. Estimate, before reset." % (
        duration, f["label"], f.get("confidence", "Low"), f.get("span_minutes", 20))


def _meta_line(a, now):
    bits = []
    if a["credits"] is not None:
        bits.append("credits %s" % format(round(a["credits"]), ","))
    if a["source"] == "Codex logs":
        bits.append("from Codex's own logs")
    bits.append(("STALE, " if a["stale"] else "") + "updated " + fmt_age(a["observed_at"], now))
    return " · ".join(bits)


def render_text(accounts, config, now):
    tz = _tz(config)
    lines = ["OVRCAST · %s" % fmt_when(now, now, tz), ""]
    for a in ordered(accounts):
        head = " · ".join(x for x in (a["tool"], a["email"] or "unknown login", a["plan"],
                                      ", ".join(a["machines"])) if x)
        lines.append(head)
        lines.append("    Status: " + account_status(a)[1])
        if a["error"]:
            lines.append("    problem: " + a["error"])
        for w in [a["five_hour"], a["weekly"]] + a["others"]:
            if w:
                lines.append("    %-14s %s" % (w["label"], _window_line(w, now, tz)))
        if a["forecast"]:
            lines.append("    ! " + _forecast_line(a, now, tz))
        if not a["error"]:
            lines.append("    " + _meta_line(a, now))
        resets = (a.get("capacity") or {}).get("resets") or {}
        if a["tool"] in ("Codex", "Claude"):
            lines.append("    Resets available: " + (str(resets["available"]) if resets.get("available") is not None else "Unknown"))
        for label, value, detail in capacity.pools(a, now):
            lines.append("    %s: %s · %s" % (label, value, detail))
        if a["note"]:
            lines.append("    note: " + a["note"])
        lines.append("")
    return "\n".join(lines)



def render_html(accounts, config, now):
    import dashboard
    return dashboard.render(accounts, config, now)
