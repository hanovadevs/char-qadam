import test from 'node:test';
import assert from 'node:assert/strict';
const storage = new Map();
globalThis.localStorage = { getItem: key => storage.get(key), setItem: (k, v) => storage.set(k, v), removeItem: k => storage.delete(k) };
globalThis.window = { location: { pathname: '/login' } };
const { api } = await import('../src/services/api.js');
test('identical concurrent GETs share one request and subsequent reads stay fresh', async () => {
  let calls = 0;
  globalThis.fetch = async () => { calls++; await new Promise(resolve => setTimeout(resolve, 5)); return { status: 200, ok: true, json: async () => ({ calls }) }; };
  const responses = await Promise.all([api.getMe(), api.getMe()]);
  assert.equal(calls, 1);
  assert.deepEqual(responses[0], responses[1]);
  await api.getMe();
  assert.equal(calls, 2);
});
test('failed requests are evicted rather than poisoning the inflight map', async () => {
  globalThis.fetch = async () => { throw new Error('offline'); };
  await assert.rejects(api.getMe(), /offline/);
  globalThis.fetch = async () => ({ status: 200, ok: true, json: async () => ({ recovered: true }) });
  assert.deepEqual(await api.getMe(), { recovered: true });
});
test('GET sharing never crosses an account change', async () => {
  let calls = 0;
  globalThis.fetch = async () => { calls++; return { status: 200, ok: true, json: async () => ({}) }; };
  api.setToken('first'); const first = api.getMe(); api.setToken('second'); const second = api.getMe();
  await Promise.all([first, second]); assert.equal(calls, 2);
});
