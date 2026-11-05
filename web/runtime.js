// Lifecycle scheduler for the silent HALOVEIL macOS adaptation.
// Timers preserve their remaining delay across pause/resume; no wakeups while paused.
(() => {
  'use strict';
  const jobs = new Map(), listeners = new Set(), errors = [];
  const nativeHost = !!window.HALOVEIL_NATIVE;
  let requested = !nativeHost;
  let active = requested && (nativeHost || !document.hidden);
  let nextID = 1, disposed = false;

  function schedule(job) {
    if (!active || job.handle != null) return;
    job.due = performance.now() + job.remaining;
    job.handle = window.setTimeout(() => {
      job.handle = null;
      if (!active || !jobs.has(job.id)) return;
      if (!job.repeat) jobs.delete(job.id);
      else job.remaining = job.delay;
      try { job.callback(); }
      finally { if (job.repeat && jobs.has(job.id)) schedule(job); }
    }, job.remaining);
  }
  function add(callback, delay, repeat) {
    if (disposed) return 0;
    const id = nextID++;
    const ms = Math.max(repeat ? 1 : 0, Number(delay) || 0);
    const job = {id, callback, repeat, delay:ms, remaining:ms, due:0, handle:null};
    jobs.set(id, job);
    schedule(job);
    return id;
  }
  function cancel(id) {
    const job = jobs.get(id);
    if (!job) return;
    if (job.handle != null) window.clearTimeout(job.handle);
    jobs.delete(id);
  }
  function update() {
    // The screen saver host owns visibility. Sonoma can report its WKWebView as
    // occluded even while it is onscreen; a standalone browser uses Page Visibility.
    const next = requested && (nativeHost || !document.hidden);
    if (next === active) return;
    active = next;
    if (!active) {
      const now = performance.now();
      for (const job of jobs.values()) {
        if (job.handle != null) {
          job.remaining = Math.max(0, job.due - now);
          window.clearTimeout(job.handle);
          job.handle = null;
        }
      }
    } else jobs.forEach(schedule);
    document.documentElement.classList.toggle('paused', !active);
    listeners.forEach(callback => callback(active));
  }
  window.HALOVEILRuntime = Object.freeze({
    after: (callback, delay) => add(callback, delay, false),
    every: (callback, delay) => add(callback, delay, true),
    cancel,
    setActive(value) { if (disposed) return; requested = !!value; update(); },
    dispose() {
      if (disposed) return;
      requested = false; update();
      for (const id of [...jobs.keys()]) cancel(id);
      listeners.clear(); disposed = true;
    },
    get disposed() { return disposed; },
    onChange(callback) { listeners.add(callback); return () => listeners.delete(callback); },
    get active() { return active; },
    get timerCount() { return jobs.size; },
    get pendingCount() { return [...jobs.values()].filter(job => job.handle != null).length; },
    errors,
  });
  const record = message => { if (errors.length < 20) errors.push(String(message)); };
  window.addEventListener('error', event => record(event.message || 'Resource failed to load'));
  window.addEventListener('unhandledrejection', event => record(event.reason));
  document.addEventListener('visibilitychange', update);
  document.documentElement.classList.toggle('paused', !active);
})();
