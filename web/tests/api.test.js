import test from 'node:test';
import assert from 'node:assert/strict';
import { ApiClient } from '../src/services/api.js';
const storage = () => { const entries = new Map(); return { getItem: key => entries.get(key), setItem: (key, value) => entries.set(key, value), removeItem: key => entries.delete(key) }; };
test('concurrent GETs share a request and account changes invalidate cached reads', async () => {
  let calls = 0;
  const client = new ApiClient({ storage: storage(), fetchImpl: async () => { calls++; await new Promise(resolve => setTimeout(resolve, 5)); return { status: 200, ok: true, json: async () => ({ calls }) }; } });
  const responses = await Promise.all([client.getMe(), client.getMe()]);
  assert.equal(calls, 1);
  assert.deepEqual(responses[0], responses[1]);
  client.setToken('new-account');
  await client.getMe();
  assert.equal(calls, 2);
});
test('failed requests do not poison future reads', async () => {
  const client = new ApiClient({ storage: storage(), fetchImpl: async () => { throw new Error('offline'); } });
  await assert.rejects(client.getMe(), /offline/);
  client.fetchImpl = async () => ({ status: 200, ok: true, json: async () => ({ recovered: true }) });
  assert.deepEqual(await client.getMe(), { recovered: true });
});

test('a transient gateway failure retries a shared read once without signing out', async () => {
  let calls = 0, logouts = 0;
  const client = new ApiClient({ storage: storage(), retryDelayMs: 1, onUnauthorized: () => logouts++, fetchImpl: async () => {
    calls++;
    return calls === 1 ? { status: 502, ok: false } : { status: 200, ok: true, json: async () => ['recovered'] };
  } });
  client.setToken('existing-session');
  assert.deepEqual(await Promise.all([client.getMe(), client.getMe()]), [['recovered'], ['recovered']]);
  assert.equal(calls, 2);
  assert.equal(logouts, 0);
  assert.equal(client.token, 'existing-session');
});

test('a gateway failure never automatically repeats a write', async () => {
  let calls = 0;
  const client = new ApiClient({ storage: storage(), retryDelayMs: 1, fetchImpl: async () => {
    calls++;
    return { status: 503, ok: false, json: async () => ({ detail: 'Temporarily unavailable' }) };
  } });
  await assert.rejects(client.updateUser('user', { status: 'ACTIVE' }), /unavailable/);
  assert.equal(calls, 1);
});

test('a stalled request times out and preserves the authenticated session', async () => {
  const client = new ApiClient({ storage: storage(), timeoutMs: 5, fetchImpl: (_url, { signal }) => new Promise((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')), { once: true });
  }) });
  client.setToken('existing-session');
  await assert.rejects(client.getMe(), /taking too long/);
  assert.equal(client.token, 'existing-session');
  client.fetchImpl = async () => ({ status: 200, ok: true, json: async () => ({ ready: true }) });
  assert.deepEqual(await client.getMe(), { ready: true });
});
