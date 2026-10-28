(() => {
  'use strict';
  const ids = ['provider', 'device', 'status', 'search', 'sort'];
  const controls = Object.fromEntries(ids.map(id => [id, document.getElementById(id)]));
  const body = document.querySelector('tbody');
  const rows = Array.from(body.rows);
  const storage = {
    get(key, fallback) { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } },
    set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch {} }
  };
  const saved = storage.get('usage-board-filters-v2', {});
  for (const id of ids) if (typeof saved[id] === 'string') controls[id].value = saved[id];
  function theme(value) {
    const chosen = value === 'night' ? 'night' : 'day';
    document.documentElement.dataset.theme = chosen;
    document.querySelectorAll('.theme-switch button').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.theme === chosen)));
    try { localStorage.setItem('usage-board-theme', chosen); } catch {}
  }
  theme(document.documentElement.dataset.theme);
  document.querySelectorAll('.theme-switch button').forEach(button => button.addEventListener('click', () => theme(button.dataset.theme)));
  function update() {
    const values = Object.fromEntries(ids.map(id => [id, controls[id].value]));
    let count = 0;
    for (const row of rows) {
      const match = (!values.provider || row.dataset.provider === values.provider) &&
        (!values.device || row.dataset.devices.split('|').includes(values.device)) &&
        (!values.status || (values.status === 'attention' ? row.dataset.state !== 'good' : row.dataset.state === values.status)) &&
        (!values.search || row.textContent.toLowerCase().includes(values.search.toLowerCase()));
      row.hidden = !match;
      if (match) count++;
    }
    rows.sort((a, b) => values.sort === 'capacity' ? Number(b.dataset.headroom) - Number(a.dataset.headroom) :
      values.sort === 'provider' ? a.dataset.provider.localeCompare(b.dataset.provider) || Number(a.dataset.index) - Number(b.dataset.index) :
      Number(a.dataset.index) - Number(b.dataset.index));
    rows.forEach(row => body.appendChild(row));
    document.getElementById('result-count').textContent = `${count} of ${rows.length} accounts`;
    document.getElementById('empty').hidden = count !== 0;
    storage.set('usage-board-filters-v2', values);
  }
  Object.values(controls).forEach(control => control.addEventListener('input', update));
  document.getElementById('clear').addEventListener('click', () => {
    ids.forEach(id => controls[id].value = id === 'sort' ? 'attention' : '');
    update();
  });
  document.querySelectorAll('.open-account').forEach(button => button.addEventListener('click', () => {
    document.querySelector('.more-menu').open = false;
    document.getElementById(button.dataset.account).showModal();
  }));
  document.querySelectorAll('dialog').forEach(dialog => {
    dialog.querySelector('.close-dialog').addEventListener('click', () => dialog.close());
    dialog.addEventListener('click', event => {
      const bounds = dialog.getBoundingClientRect();
      if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
    });
  });
  document.getElementById('refresh').addEventListener('click', () => location.reload());
  document.getElementById('collect').addEventListener('click', () => {
    const status = document.getElementById('action-status');
    status.textContent = 'Refresh requested. Account readings may take up to 3 minutes.';
    setTimeout(() => { status.textContent = ''; }, 8000);
  });
  document.getElementById('export').addEventListener('click', () => {
    const text = document.getElementById('snapshot').textContent;
    const url = URL.createObjectURL(new Blob([text], {type: 'application/json'}));
    const link = document.createElement('a'); link.href = url; link.download = 'usage-board-snapshot.json'; link.click();
    document.querySelector('.more-menu').open = false;
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  update();
  setInterval(() => {
    if (!document.querySelector('dialog[open], details[open]') && !['INPUT', 'SELECT'].includes(document.activeElement?.tagName)) location.reload();
  }, 60000);
})();
