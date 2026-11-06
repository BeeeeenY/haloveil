// Account telemetry is independent of the decorative animation and its demo counters.
(() => {
  'use strict';
  const panel = document.getElementById('codexStatus');
  const badge = document.getElementById('codexBadge');
  const windows = document.getElementById('codexWindows');
  const resetCount = document.getElementById('codexResetCount');
  const expiry = document.getElementById('codexExpiry');
  const caption = document.getElementById('codexCaption');
  const finite = value => typeof value === 'number' && Number.isFinite(value);
  let snapshot = null;
  const date = seconds => {
    if (!finite(seconds) || seconds <= 0 || seconds >= 253402300800) return 'unknown';
    const d = new Date(seconds * 1000), pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };
  const duration = minutes => {
    if (!finite(minutes) || minutes <= 0) return 'WINDOW';
    if (minutes % 10080 === 0) return `${minutes / 10080}W`;
    if (minutes % 1440 === 0) return `${minutes / 1440}D`;
    if (minutes % 60 === 0) return `${minutes / 60}H`;
    return `${minutes}M`;
  };
  const text = (tag, cls, value) => {
    const element = document.createElement(tag);
    element.className = cls; element.textContent = value;
    return element;
  };
  function render() {
    const now = Date.now() / 1000;
    const valid = snapshot?.state === 'ok' && finite(snapshot.fetchedAt) && snapshot.fetchedAt > 0 && snapshot.fetchedAt <= now + 60;
    const stale = valid && now - snapshot.fetchedAt > 900;
    badge.textContent = valid ? (stale ? 'STALE' : 'SYNCED') : 'NO DATA';
    panel.dataset.state = valid ? (stale ? 'stale' : 'ok') : 'unavailable';
    windows.replaceChildren();
    const all = valid && Array.isArray(snapshot.limits) ? snapshot.limits.flatMap(bucket =>
      Array.isArray(bucket.windows) ? bucket.windows.map(window => ({bucket, window})) : []) : [];
    for (const {bucket, window} of all.slice(0, 2)) {
      const row = text('div', 'quota-window', '');
      const used = finite(window.usedPercent) ? Math.max(0, Math.min(100, window.usedPercent)) : null;
      const elapsed = finite(window.resetsAt) && window.resetsAt <= now;
      const label = `${bucket.id === 'codex' ? '' : `${bucket.name} / `}${duration(window.windowDurationMins)}`;
      const value = used === null || elapsed ? 'usage unknown' : `${Math.round(used)}% used · ${Math.round(100 - used)}% left`;
      row.append(text('div', 'quota-value', `${label}  ${value}`));
      const track = text('div', 'quota-track', '');
      const fill = text('i', '', '');
      fill.style.width = used === null || elapsed ? '0%' : `${used}%`;
      track.append(fill);
      row.append(track, text('div', 'quota-renews', elapsed ? 'RENEWAL DUE · awaiting sync' : `RENEWS ${date(window.resetsAt)}`));
      windows.append(row);
    }
    if (!all.length) windows.append(text('div', 'quota-empty', valid ? 'Usage limits unavailable' : 'Waiting for account snapshot'));
    const reset = valid ? snapshot.fullReset : null;
    const expired = finite(reset?.expiresAt) && reset.expiresAt <= now;
    resetCount.textContent = finite(reset?.availableCount) ? `${reset.availableCount} AVAILABLE${expired ? ' / CHECK SYNC' : ''}` : 'UNKNOWN';
    expiry.textContent = expired ? 'EXPIRY PASSED · awaiting sync' : finite(reset?.expiresAt)
      ? `NEXT KNOWN EXPIRY ${date(reset.expiresAt)}`
      : reset?.availableCount === 0 ? 'No available resets' : 'Expiry unavailable';
    // A capped server detail list may not include every earned reset.
    expiry.title = 'Earliest future expiry in the available reset details returned by Codex.';
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const more = all.length > 2 ? ` · 2/${all.length} windows` : '';
    caption.textContent = valid ? `${stale ? 'STALE · ' : ''}Updated ${date(snapshot.fetchedAt)} · ${zone}${more}` : 'Local account status · decorative panels are demo';
    caption.title = caption.textContent;
  }
  window.HALOVEILAgentStatus = Object.freeze({
    update(value) { snapshot = value; render(); },
  });
  window.HALOVEILRuntime.every(render, 5000);
  render();
})();
