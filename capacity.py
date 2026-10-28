"""Display-safe optional billing and reset data from CodexBar 0.81 / Codex RPC.

Missing, zero, disabled, expired and unreadable are distinct states. Monetary
pools remain separate; quota percentages are never converted into money.
"""
import math
import re
from datetime import datetime, timezone


def number(value):
    if isinstance(value, bool):
        return None
    try:
        value = float(value)
        return value if math.isfinite(value) and value >= 0 else None
    except (ValueError, TypeError):
        return None


def details(usage):
    result = []
    for section in usage.get("details") or []:
        if not isinstance(section, dict):
            continue
        for row in section.get("rows") or []:
            if isinstance(row, dict):
                result.append({k: str(row[k])[:800] for k in ("id", "label", "value", "secondaryValue")
                               if isinstance(row.get(k), (str, int, float))})
    return result


def normalize(row):
    usage = row.get("usage") or {}
    rows = details(usage)
    raw = row.get("resetCredits") or usage.get("codexResetCredits") or {}
    count = number(raw.get("available", raw.get("availableCount")))
    resets = {"available": int(count) if count is not None and count.is_integer() else None,
              "expires_at": raw.get("nextExpiresAt"), "details": [], "reported": bool(raw)}
    for d in rows:
        if "reset" in (d.get("id", "") + " " + d.get("label", "")).lower():
            resets["details"].append(d)
            match = re.search(r"\b(\d+) available\b", d.get("value", ""), re.I)
            if match:
                resets["available"] = int(match[1])
                resets["reported"] = True
    cost = usage.get("providerCost") or {}
    credits = row.get("credits") or {}
    balance = number(credits.get("remaining")) if credits.get("balanceReadSucceeded") is not False else None
    if balance is None and credits.get("balanceReadSucceeded") is not False:
        balance = number(cost.get("balance"))
    return {"resets": resets, "cost": {k: v for k, v in cost.items()
             if k in ("currencyCode", "period", "updatedAt", "balanceUpdatedAt", "enabled", "autoReloadEnabled")
             and isinstance(v, (str, bool))} | {
                 k: number(cost.get(k)) for k in ("used", "limit", "balance")},
            "balance": balance, "balance_at": credits.get("updatedAt") or cost.get("balanceUpdatedAt"),
            "details": rows, "limited": usage.get("dataConfidence") == "percentOnly",
            "renewal": usage.get("subscriptionRenewsAt"), "expiry": usage.get("subscriptionExpiresAt")}


def pools(account, now=None):
    """Named display rows, including explicit gaps for providers with unread pools."""
    now = now or datetime.now(timezone.utc)
    data = account.get("capacity") or {}
    cost = data.get("cost") or {}
    rows = []
    if account["tool"] == "Codex":
        balance = data.get("balance", account.get("credits"))
        rows.append(("Codex credits", "Unknown" if balance is None else f"{balance:,.2f} credits",
                     "Provider credit units; separate from included quota"))
    elif account["tool"] == "Claude":
        categories = [("Cloud credits", ("cloud-credit", "cloud credit"),
                       "Promotional cloud-session credits; expiry applies"),
                      ("Extra usage", ("extra-usage", "extra usage", "usage credits"),
                       "Paid usage beyond included plan limits"),
                      ("API / Console credits", ("api-credit", "api credit", "console credit"),
                       "Separate Console billing pool"),
                      ("Included monthly API credits", ("monthly-api", "monthly api"),
                       "Separate allowance; verify linked organization and expiry")]
        for title, needles, explanation in categories:
            matched = [r for r in data.get("details", []) if any(n in
                       (r.get("id", "") + " " + r.get("label", "")).lower() for n in needles)]
            if title == "API / Console credits":
                matched = [r for r in matched if "monthly" not in (r.get("id", "") + r.get("label", "")).lower()]
            if matched:
                value = "; ".join(r.get("value", "Unknown") for r in matched)
                secondary = "; ".join(r.get("secondaryValue", "") for r in matched)
                if title == "Cloud credits":
                    match = re.search(r"Expires\s+(\S+)", secondary, re.I)
                    if match:
                        try:
                            expiry = datetime.fromisoformat(match[1].replace("Z", "+00:00"))
                            if expiry <= now:
                                value = "Expired"
                        except (TypeError, ValueError):
                            pass
                rows.append((title, value, secondary or explanation))
            elif title == "Extra usage" and cost.get("currencyCode") and cost.get("used") is not None:
                currency = cost["currencyCode"]
                value = f'{cost["used"]:,.2f} {currency} spent'
                if cost.get("limit") is not None:
                    value += f' / {cost["limit"]:,.2f} cap'
                if cost.get("balance") is not None:
                    value += f' · {cost["balance"]:,.2f} balance'
                rows.append((title, value, explanation))
            else:
                rows.append((title, "Unknown", "Current source does not report this balance"))
    elif account["tool"] == "Claude Platform":
        for row in data.get("details", []):
            rows.append((row.get("label", "Billing"), row.get("value", "Unknown"),
                         row.get("secondaryValue", "")))
        if not rows:
            rows.append(("Console balance", "Unknown" if data.get("balance") is None else
                         f'{data["balance"]:,.2f} {cost.get("currencyCode", "USD")}', "Console organization"))
    else:
        rows.append(("Paid credits", "Unknown", "Current source does not report a paid balance"))
    return rows
