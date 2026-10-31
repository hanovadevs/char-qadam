// Session-local display cache. Server authorization remains mandatory for writes.
export class ReadCache {
  constructor({ now = Date.now, maxEntries = 100 } = {}) {
    this.now = now;
    this.maxEntries = maxEntries;
    this.entries = new Map();
    this.pending = new Map();
    this.version = 0;
    this.listeners = new Set();
  }

  peek(key) { return this.entries.get(key); }

  isFresh(key, maxAge = 30000) {
    const entry = this.peek(key);
    return Boolean(entry && this.now() - entry.at < maxAge);
  }

  fetch(key, load) {
    if (this.pending.has(key)) return this.pending.get(key);
    const version = this.version;
    const request = Promise.resolve().then(load).then((data) => {
      if (version === this.version) {
        this.entries.delete(key);
        this.entries.set(key, { data, at: this.now() });
        while (this.entries.size > this.maxEntries) this.entries.delete(this.entries.keys().next().value);
      }
      return data;
    }).finally(() => {
      if (this.pending.get(key) === request) this.pending.delete(key);
    });
    this.pending.set(key, request);
    return request;
  }

  invalidate() {
    this.version++;
    this.entries.clear();
    this.pending.clear();
    for (const listener of this.listeners) listener();
  }

  subscribe(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

export function queryPath(path, params = {}) {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '' && value !== 'ALL') query.set(key, value);
  }
  query.sort();
  return query.size ? `${path}?${query}` : path;
}
