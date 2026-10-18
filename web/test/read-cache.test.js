import test from 'node:test';
import assert from 'node:assert/strict';
import { ReadCache, queryPath } from '../src/services/read-cache.js';
import { ApiClient } from '../src/services/api.js';

const deferred = () => Promise.withResolvers();
const response = (data, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });

test('concurrent readers share a request while distinct filters stay independent', async () => {
  const cache = new ReadCache();
  const pending = deferred();
  let calls = 0;
  const first = cache.fetch('/users?search=ali', () => { calls++; return pending.promise; });
  const second = cache.fetch('/users?search=ali', () => { calls++; });
  const other = cache.fetch('/users?search=ayesha', () => ['ayesha']);
  pending.resolve(['ali']);
  assert.deepEqual(await first, ['ali']);
  assert.deepEqual(await second, ['ali']);
  assert.deepEqual(await other, ['ayesha']);
  assert.equal(calls, 1);
});

test('a pre-mutation response cannot replace a newer snapshot or pending request', async () => {
  const cache = new ReadCache();
  const old = deferred(), fresh = deferred();
  const first = cache.fetch('/balance', () => old.promise);
  await Promise.resolve();
  cache.invalidate();
  const second = cache.fetch('/balance', () => fresh.promise);
  old.resolve(10);
  await first;
  assert.equal(cache.peek('/balance'), undefined);
  assert.equal(cache.pending.get('/balance'), second);
  fresh.resolve(20);
  await second;
  assert.equal(cache.peek('/balance').data, 20);
});

test('cache freshness expires and its size remains bounded', async () => {
  let now = 0;
  const cache = new ReadCache({ now: () => now, maxEntries: 2 });
  await cache.fetch('/one', () => []);
  assert.equal(cache.isFresh('/one'), true);
  now = 30001;
  assert.equal(cache.isFresh('/one'), false);
  assert.deepEqual(cache.peek('/one').data, []); // Saved empty results are usable.
  await cache.fetch('/two', () => 2);
  await cache.fetch('/three', () => 3);
  assert.equal(cache.entries.size, 2);
  assert.equal(cache.peek('/one'), undefined);
});

test('successful admin writes invalidate related page snapshots', async () => {
  let balance = 10;
  const api = new ApiClient({ fetchImpl: async (_url, options) => {
    if (options.method === 'PATCH') { balance = 20; return response({ ok: true }); }
    return response({ balance });
  } });
  api.setToken('session');
  await api.request('/admin/users');
  assert.equal(api.cache.peek('/admin/users').data.balance, 10);
  await api.request('/admin/users/test', { method: 'PATCH' });
  assert.equal(api.cache.peek('/admin/users'), undefined);
  assert.equal((await api.request('/admin/users')).balance, 20);
});

test('a delayed 401 from an old admin session cannot log out its replacement', async (t) => {
  t.mock.method(console, 'error', () => {});
  const pending = deferred();
  let logouts = 0;
  const api = new ApiClient({ fetchImpl: () => pending.promise, onUnauthorized: () => logouts++ });
  api.setToken('old-session');
  const read = api.request('/admin/users');
  await Promise.resolve();
  api.setToken('new-session');
  pending.resolve(response({}, 401));
  await assert.rejects(read, /previous session/);
  assert.equal(api.token, 'new-session');
  assert.equal(logouts, 0);
});

test('logout prevents a late successful response from entering another session cache', async (t) => {
  t.mock.method(console, 'error', () => {});
  const pending = deferred();
  const api = new ApiClient({ fetchImpl: () => pending.promise });
  api.setToken('old-session');
  const read = api.request('/admin/users');
  await Promise.resolve();
  api.setToken(null);
  api.setToken('different-session');
  pending.resolve(response([{ email: 'old-private-data@example.com' }]));
  await assert.rejects(read, /previous session/);
  assert.equal(api.cache.peek('/admin/users'), undefined);
});

test('temporary network failure preserves the current admin login', async (t) => {
  t.mock.method(console, 'error', () => {});
  const api = new ApiClient({ fetchImpl: async () => { throw Error('Offline'); } });
  api.setToken('valid-session');
  await assert.rejects(api.getMe(), /Offline/);
  assert.equal(api.token, 'valid-session');
});

test('filtered cache keys normalize empty values and encode search text', () => {
  assert.equal(queryPath('/users', { status: 'ALL', search: '', limit: undefined }), '/users');
  assert.equal(queryPath('/users', { status: 'ACTIVE', search: 'ali+a@example.com' }), '/users?search=ali%2Ba%40example.com&status=ACTIVE');
});
