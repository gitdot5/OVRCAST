"""Compact local overview with full account detail in accessible native dialogs."""
import html
import json
import base64
from functools import lru_cache
from pathlib import Path
import board
import capacity

ROOT = Path(__file__).parent
e = html.escape
URLS = {
    "Codex": ("https://chatgpt.com/codex/settings/usage", "https://chatgpt.com/codex/settings/usage"),
    "Claude": ("https://claude.ai/settings/usage", "https://platform.claude.com/settings/billing"),
    "Claude Platform": ("https://platform.claude.com/settings/usage", "https://platform.claude.com/settings/billing"),
    "Antigravity": ("https://antigravity.google/", None),
}
PROVIDER_IMAGES = {'Codex': 'codex.png', 'Claude': 'claude.png', 'Claude Platform': 'claude.png',
                   'Antigravity': 'antigravity.png'}
DEVICE_IMAGES = {'MacBook': 'macbook.png', 'Mini': 'mac-mini.png', 'Studio': 'mac-studio.png'}


@lru_cache(maxsize=16)
def asset_uri(group, filename):
    """Embed our bundled assets so the generated board stays self-contained."""
    path = ROOT / 'assets' / group / filename
    if not path.is_file():
        return None
    return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode('ascii')


def provider_image(tool):
    filename = PROVIDER_IMAGES.get(tool)
    uri = asset_uri('providers', filename) if filename else None
    return f'<img class="provider-image" src="{uri}" width="28" height="28" alt="" aria-hidden="true">' if uri else ''


def device_images(machines, detail=False):
    chips = []
    for machine in machines:
        filename = DEVICE_IMAGES.get(machine)
        uri = asset_uri('devices', filename) if filename else None
        image = f'<img class="device-image" src="{uri}" width="30" height="22" alt="" aria-hidden="true">' if uri else ''
        chips.append(f'<span class="device-chip" title="{e(machine)}">{image}<span>{e(machine)}</span></span>')
    return '<span class="device-list%s">%s</span>' % (' detail-devices' if detail else '', ''.join(chips))


def countdown(dt, now):
    minutes = max(0, int((dt - now).total_seconds() / 60))
    if minutes >= 1440:
        return f"{minutes // 1440}d {(minutes % 1440) // 60}h"
    return f"{minutes // 60}h {minutes % 60}m" if minutes >= 60 else f"{minutes}m"


def window(w, now, tz, named=False):
    if not w:
        return '<span class="unreported" title="This window is not reported" aria-label="Not reported">—</span>'
    if w["reset_passed"]:
        return '<span class="pending" title="Reset time passed; waiting for a current reading">Pending</span>'
    left = max(0, min(100, 100 - w["used"]))
    cls = board.status(left)[0]
    label = w["label"]
    title = f'{label}: {left}% left'
    if w.get("resets_at"):
        title += ' · Resets ' + board.fmt_when(w["resets_at"], now, tz)
    caption = f'<small class="window-name">{e(label)}</small>' if named else ''
    return (f'<div class="quota {cls}" title="{e(title)}"><strong>{left}%</strong>'
            f'<meter min="0" max="100" value="{left}" aria-label="{e(label)} remaining">{left}%</meter>{caption}</div>')


def reset_cell(a, now, tz):
    data = (a.get("capacity") or {}).get("resets") or {}
    count = data.get("available")
    if count is None:
        return '<span class="unreported" title="Unknown: current source does not report saved resets">—</span>'
    stale = a.get("stale") or a.get("last_check_failed")
    cls = 'saved-reset' if count and not stale else 'reset-count'
    suffix = '<small>last known</small>' if stale else ''
    return f'<span class="{cls}" title="{count} saved resets available">{count}</span>{suffix}'


def pool_html(pool):
    label, value, detail = pool
    return f'<div class="pool"><span>{e(label)}</span><strong>{e(value)}</strong><small>{e(detail)}</small></div>'


def credit_summary(a, pools):
    if a["tool"] == "Codex":
        extra = a.get("capacity") or {}
        value = extra.get("balance", a.get("credits"))
        if value is not None:
            return f'<strong class="credit-number" title="{value:,.2f} Codex credits">{value:,.0f}</strong><small>Codex credits</small>'
    for label, value, detail in pools:
        if value != "Unknown":
            return f'<strong class="credit-number clip" title="{e(value)}">{e(value)}</strong><small>{e(label)}</small>'
    return '<span class="unreported" title="Unknown: current source does not report billing">—</span><small>Not reported</small>'


def next_reset(a, now, tz):
    windows = board.all_windows(a)
    if any(w["reset_passed"] for w in windows):
        return '<span class="pending">Pending</span><small>Awaiting reading</small>'
    future = [w for w in windows if w.get("resets_at") and w["resets_at"] > now]
    if not future:
        return '<span class="unreported">—</span>'
    w = min(future, key=lambda w: w["resets_at"])
    when = board.fmt_when(w["resets_at"], now, tz)
    label = 'Session' if w["minutes"] == 300 else 'Weekly' if w["minutes"] == 10080 else w["label"]
    return (f'<strong class="reset-time" title="{e(when)}">{e(countdown(w["resets_at"], now))}</strong>'
            f'<small class="clip" title="{e(when)}">{e(label)} · {e(w["resets_at"].astimezone(tz).strftime("%a"))}</small>')


def detail_dialog(a, index, now, tz):
    cls, status = board.account_status(a)
    extra = a.get("capacity") or {}
    windows = ''.join(f'<div class="detail-quota"><div><strong>{e(w["label"])}</strong>'
                      f'<small>{e(board._window_line(w, now, tz))}</small></div>{window(w, now, tz)}</div>'
                      for w in board.all_windows(a)) or '<p class="muted">No current quota reading.</p>'
    pools = ''.join(pool_html(p) for p in capacity.pools(a, now))
    data = extra.get("resets") or {}
    count = data.get("available")
    count_text = str(count) if count is not None else 'Unknown'
    inventory = []
    for c in data.get("inventory", []):
        expiry = board.parse_time(c.get("expiresAt"))
        inventory.append('<p>%s%s</p>' % (e(c.get("title") or "Saved reset"),
                         ' · Expires ' + e(board.fmt_when(expiry, now, tz)) if expiry else ''))
    if data.get("expires_at"):
        dt = board.parse_time(data["expires_at"])
        if dt:
            inventory.append('<p>Next expiry: %s</p>' % e(board.fmt_when(dt, now, tz)))
    for d in data.get("details", []):
        inventory.append(f'<p>{e(d.get("value", ""))} {e(d.get("secondaryValue", ""))}</p>')
    forecast = f'<section class="detail-section"><h3>Usage pace</h3><p>{e(board._forecast_line(a, now, tz))}</p></section>' if a.get("forecast") else ''
    problem = ' '.join(filter(None, [a.get("error"), a.get("note")]))
    diagnostic = f'<p class="diagnostic">{e(problem)}</p>' if problem else ''
    if extra.get("limited"):
        diagnostic += '<p>Current source reports percentages only. Additional balances need an authorized richer source.</p>'
    source = ' · '.join(filter(None, [a.get("source"), a.get("reading_source")])) or 'Unknown'
    usage_url, billing_url = URLS.get(a["tool"], (None, None))
    links = ''.join(f'<a class="button" href="{url}" target="_blank" rel="noopener noreferrer">{label}</a>'
                    for url, label in ((usage_url, 'Open usage'), (billing_url, 'Open billing')) if url)
    cost = extra.get('cost') or {}
    switch = lambda v: {True: 'On', False: 'Off'}.get(v, 'Unknown')
    dates = ''.join(f'<p>{label}: {e(str(extra[key]))}</p>' for label, key in
                    [('Plan renews', 'renewal'), ('Plan expires', 'expiry')] if extra.get(key))
    return f'''<dialog id="account-{index}" aria-labelledby="account-title-{index}">
<div class="dialog-head"><div class="dialog-identity">{provider_image(a['tool'])}<div><p class="eyebrow">ACCOUNT DETAILS</p><h2 id="account-title-{index}">{e(a['tool'])}</h2><p>{e(a['email'] or 'Unknown login')}</p></div></div><button class="close-dialog" type="button" aria-label="Close account details">Close</button></div>
<div class="dialog-meta"><span class="badge {cls}">{e(status)}</span><span>{e(a.get('plan') or 'Plan unknown')}</span></div>{device_images(a['machines'], detail=True)}
<section class="detail-section"><h3>Included allowances</h3>{windows}</section>{forecast}
<section class="detail-section"><h3>Resets available <span class="detail-count">{e(count_text)}</span></h3>{''.join(inventory)}<p class="muted">Saved resets are separate from automatic quota resets.</p></section>
<section class="detail-section"><h3>Credits &amp; spending</h3><div class="pool-grid">{pools}</div><p class="muted">Auto-reload: {switch(cost.get('autoReloadEnabled'))} · Extra usage: {switch(cost.get('enabled'))}</p>{dates}</section>
<section class="detail-section"><h3>Reading details</h3><p>Last successful reading: {e(board.fmt_age(a['observed_at'], now))}</p><p>Source: {e(source)}</p>{diagnostic}</section><div class="dialog-actions">{links}</div></dialog>'''


def render(accounts, config, now):
    tz = board._tz(config)
    rows, dialogs, payload = [], [], []
    ordered = board.ordered(accounts)
    short_status = {'Reading unavailable': 'Unavailable', 'Awaiting current reading': 'Needs refresh',
                    'Included limit reached': 'Limit reached', 'Model limit reached': 'Model capped',
                    'At risk before reset': 'Pace risk', 'Limited headroom': 'Running low', 'Available': 'Available'}
    for index, a in enumerate(ordered):
        cls, state = board.account_status(a)
        active = [m for m in a['machines'] if 'retired' not in m.lower()]
        model_windows = a.get('others') or []
        model = model_windows[0] if model_windows else None
        model_html = window(model, now, tz, named=True)
        if len(model_windows) > 1:
            model_html += f'<small>+{len(model_windows)-1} in details</small>'
        age = board.fmt_age(a['observed_at'], now)
        health = 'Last known · ' if a.get('stale') or a.get('last_check_failed') else ''
        source = ' · '.join(filter(None, [a.get('source'), a.get('reading_source')]))
        pools = capacity.pools(a, now)
        email = a['email'] or 'Unknown login'
        headroom = board._min_left(a)
        rows.append(f'''<tr data-provider="{e(a['tool'])}" data-devices="{e('|'.join(active))}" data-state="{cls}" data-index="{index}" data-headroom="{headroom if headroom is not None else -1}">
<td data-label="Account"><div class="account-identity">{provider_image(a['tool'])}<div class="identity-text"><div class="account-top"><strong class="provider" title="{e(a.get('plan') or 'Plan unknown')}">{e(a['tool'])}</strong>{device_images(active)}</div><span class="email" title="{e(email)}">{e(email)}</span></div></div></td>
<td data-label="Session">{window(a.get('five_hour'), now, tz)}</td><td data-label="Weekly">{window(a.get('weekly'), now, tz, named=bool(a.get('weekly') and a['weekly']['label'] != 'Weekly'))}</td><td data-label="Model">{model_html}</td>
<td data-label="Next reset">{next_reset(a, now, tz)}</td><td data-label="Resets available">{reset_cell(a, now, tz)}</td><td data-label="Credits">{credit_summary(a, pools)}</td>
<td data-label="Status"><span class="badge {cls}" title="{e(state)}">{e(short_status.get(state, state))}</span><small class="reading-age" title="{e(source or 'Unknown source')}">{e(health + age)}</small></td>
<td class="row-action"><button type="button" class="open-account" data-account="account-{index}" aria-label="Details for {e(a['tool'] + ' ' + email)}">Details</button></td></tr>''')
        dialogs.append(detail_dialog(a, index, now, tz))
        item = board._to_state(a)
        item['status'] = state
        payload.append(item)
    ready = sum(board.account_status(a)[0] == 'good' for a in accounts)
    inventories = [(a.get('capacity') or {}).get('resets', {}).get('available')
                   if not a.get('stale') and not a.get('last_check_failed') and not a.get('error') else None
                   for a in accounts if a['tool'] in ('Codex', 'Claude')]
    coverage = sum(c is not None for c in inventories)
    saved = str(sum(c for c in inventories if c is not None)) if coverage else '—'
    options = lambda values: ''.join(f'<option value="{e(v)}">{e(v)}</option>' for v in sorted(set(values)))
    providers = options(a['tool'] for a in accounts)
    devices = options(m for a in accounts for m in a['machines'] if 'retired' not in m.lower())
    suggestions = []
    for tool in sorted({a['tool'] for a in accounts}):
        candidates = [a for a in accounts if a['tool'] == tool and board.account_status(a)[0] == 'good']
        if candidates:
            best = max(candidates, key=lambda a: board._min_left(a) if board._min_left(a) is not None else -1)
            suggestions.append(f'{tool} · {", ".join(m for m in best["machines"] if "retired" not in m.lower())}')
    suggestion = e(' / '.join(suggestions)) or 'Waiting for fresh account readings'
    css, js = (ROOT / 'dashboard.css').read_text(), (ROOT / 'dashboard.js').read_text()
    data = json.dumps({'generated_at': board.iso(now), 'accounts': payload}, ensure_ascii=True).replace('<', '\\u003c')
    clock = now.astimezone(tz).strftime('%I:%M %p').lstrip('0')
    return f'''<!doctype html><html lang="en" data-theme="day"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light dark"><title>OVRCAST</title>
<script>try{{document.documentElement.dataset.theme=localStorage.getItem('usage-board-theme')==='night'?'night':'day'}}catch{{}}</script><style>{css}</style></head><body><main>
<header><div class="wordmark"><h1>OVRCAST</h1><span class="wordmark-sub">All your AI. One clear view.</span></div><div class="header-actions"><div class="theme-switch" role="group" aria-label="Appearance"><button type="button" data-theme="day" aria-pressed="true">Day</button><button type="button" data-theme="night" aria-pressed="false">Night</button></div><a class="button primary" href="usageboard://refresh" id="collect">Refresh usage</a><details class="more-menu"><summary>More</summary><div><button id="refresh" type="button">Refresh view</button><button id="export" type="button">Export snapshot</button></div></details></div></header>
<section class="overview" aria-label="Account overview"><div><strong>{len(accounts)}</strong><span>Accounts</span></div><div><strong class="good">{ready}</strong><span>Available now</span></div><div><strong>{len(accounts)-ready}</strong><span>Need attention</span></div><div><strong>{saved}</strong><span>Saved resets <small>{coverage} of {len(inventories)} accounts reporting</small></span></div></section>
<form class="filters" onsubmit="return false" aria-label="Filter accounts"><label class="search"><span class="sr-only">Find account</span><input id="search" type="search" placeholder="Find an account…"></label><label><span class="sr-only">Provider</span><select id="provider"><option value="">All providers</option>{providers}</select></label><label><span class="sr-only">Device</span><select id="device"><option value="">All devices</option>{devices}</select></label><label><span class="sr-only">Status</span><select id="status"><option value="">All statuses</option><option value="good">Available</option><option value="attention">Needs attention</option><option value="unknown">Reading unavailable</option></select></label><label><span class="sr-only">Sort</span><select id="sort"><option value="attention">Attention first</option><option value="capacity">Most capacity</option><option value="provider">Provider</option></select></label><button type="button" id="clear">Clear</button></form>
<div class="table-wrap"><table><caption class="sr-only">AI account capacity, saved resets and credits</caption><colgroup><col class="col-account"><col class="col-quota"><col class="col-quota"><col class="col-model"><col class="col-reset"><col class="col-saved"><col class="col-credits"><col class="col-status"><col class="col-action"></colgroup><thead><tr><th scope="col">Account</th><th scope="col">Session</th><th scope="col">Weekly</th><th scope="col">Model</th><th scope="col">Next reset</th><th scope="col" title="Saved resets available">Resets</th><th scope="col">Credits</th><th scope="col">Status</th><th scope="col"><span class="sr-only">Details</span></th></tr></thead><tbody>{''.join(rows)}</tbody></table><p id="empty" hidden>No accounts match. Try another filter.</p></div>
<div class="board-footer"><span id="result-count" role="status" aria-live="polite">{len(accounts)} accounts</span><span class="suggestion" title="Suggested accounts use fresh readings and all reported limits.">Available: {suggestion}</span><span class="updated">Updated {e(clock)} ET · Auto refresh</span></div>
<p class="data-note">Percentages show allowance remaining. — means not reported; zero is a verified balance. Open Details for billing pools, full reset dates and source information.</p><p id="action-status" role="status" aria-live="polite"></p>
<noscript>JavaScript enables filters, appearance and account panels. Complete readings are available in the text snapshot.</noscript>
{''.join(dialogs)}</main><script type="application/json" id="snapshot">{data}</script><script>{js}</script></body></html>'''
