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
