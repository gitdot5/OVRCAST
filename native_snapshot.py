"""Small, credential-free presentation contract for the native menu bar app."""
import board
import capacity
import re


def credit_expiry(detail):
    match = re.search(r"Expires\s+(\d{4}-\d{2}-\d{2}T[0-9:.]+(?:Z|[+-][0-9:]+))", detail, re.I)
    return match[1] if match and board.parse_time(match[1]) else None


def build(accounts, now):
    rows = []
    for a in board.ordered(accounts):
        severity, status = board.account_status(a)
        extra = a.get("capacity") or {}
        resets = extra.get("resets") or {}
        reset_details = []
        for credit in resets.get("inventory", []):
            expiry = board.parse_time(credit.get("expiresAt"))
            reset_details.append("%s%s" % (credit.get("title") or "Saved reset",
                                 " · Expires " + board.iso(expiry) if expiry else ""))
        for d in resets.get("details", []):
            reset_details.append(" ".join(str(d[k]) for k in ("value", "secondaryValue") if d.get(k)))
        rows.append({
            "id": a["key"], "provider": a["tool"], "email": a.get("email") or "Unknown account",
            "plan": a.get("plan") or "Plan unknown", "machines": a["machines"],
            "severity": severity, "status": status,
            "requiresSignIn": bool(a.get("requires_sign_in")),
            "fresh": not (a.get("stale") or a.get("error") or a.get("last_check_failed")),
            "observedAt": board.iso(a["observed_at"]) if a.get("observed_at") else None,
            "source": " · ".join(filter(None, [a.get("source"), a.get("reading_source")])),
            "issue": " ".join(filter(None, [a.get("error"), a.get("note")])),
            "pace": board._forecast_line(a, now, board.UTC) if a.get("forecast") else None,
            "quotas": [{"label": w["label"], "remaining": 100 - w["used"],
                        "resetsAt": board.iso(w["resets_at"]) if w.get("resets_at") else None,
                        "resetPassed": w["reset_passed"]} for w in board.all_windows(a)],
            "savedResets": resets.get("available"), "resetDetails": reset_details,
            "credits": [{"name": name, "value": value, "detail": detail, "expiresAt": credit_expiry(detail)}
                        for name, value, detail in capacity.pools(a, now)],
        })
    return {"version": 1, "generatedAt": board.iso(now), "accounts": rows}
