import test from 'node:test';
import assert from 'node:assert/strict';
import React from 'react';
import { create, act } from 'react-test-renderer';
import { api } from '../src/services/api.js';
import { useAdminQuery } from '../src/hooks/use-admin-query.js';

const json = (data) => new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });

function Probe({ path }) {
  const result = useAdminQuery(path, []);
  return React.createElement('output', { loading: result.loading, busy: result.isRefreshing }, JSON.stringify(result.data));
}

function setup(t) {
  const originalFetch = api.fetchImpl;
  const originalWindow = globalThis.window, originalDocument = globalThis.document;
  globalThis.window = new EventTarget();
  globalThis.document = Object.assign(new EventTarget(), { visibilityState: 'visible' });
  api.setToken('local-render-test');
  let view;
  t.after(() => {
    act(() => view?.unmount());
    api.setToken(null);
    api.fetchImpl = originalFetch;
    globalThis.window = originalWindow;
    globalThis.document = originalDocument;
  });
  return { mount: (node) => { act(() => { view = create(node); }); return view; } };
}

test('returning to a cached admin page renders its saved rows without a loading screen', async (t) => {
  const fixture = setup(t);
  let calls = 0;
  api.fetchImpl = async () => { calls++; return json([]); };
  await api.cache.fetch('/admin/users', () => [{ email: 'saved@example.com' }]);
  const view = fixture.mount(React.createElement(Probe, { path: '/admin/users' }));
  const output = view.root.findByType('output');
  assert.equal(output.props.loading, false);
  assert.match(output.props.children, /saved@example.com/);
  assert.equal(calls, 0);
});

test('a slow previous search cannot overwrite the selected filter', async (t) => {
  const fixture = setup(t);
  const old = Promise.withResolvers(), current = Promise.withResolvers();
  api.fetchImpl = (url) => url.includes('old') ? old.promise : current.promise;
  let view;
  await act(async () => { view = fixture.mount(React.createElement(Probe, { path: '/admin/users?search=old' })); });
  await act(async () => { view.update(React.createElement(Probe, { path: '/admin/users?search=new' })); });
  await act(async () => { current.resolve(json([{ email: 'new@example.com' }])); });
  assert.match(view.root.findByType('output').props.children, /new@example.com/);
  await act(async () => { old.resolve(json([{ email: 'old@example.com' }])); });
  assert.match(view.root.findByType('output').props.children, /new@example.com/);
  assert.doesNotMatch(view.root.findByType('output').props.children, /old@example.com/);
});

test('a completed admin edit refreshes all mounted readers while keeping loaded content visible', async (t) => {
  const fixture = setup(t);
  let reads = 0;
  const updated = Promise.withResolvers();
  api.fetchImpl = async (_url, options) => {
    if (options.method === 'PATCH') return json({ ok: true });
    reads++;
    return reads === 1 ? json([{ balance: 10 }]) : updated.promise;
  };
  let view;
  await act(async () => { view = fixture.mount(React.createElement('section', null,
    React.createElement(Probe, { path: '/admin/users' }),
    React.createElement(Probe, { path: '/admin/users' }))); });
  assert.equal(reads, 1);
  await act(async () => { await api.request('/admin/users/test', { method: 'PATCH' }); });
  assert.equal(reads, 2);
  for (const output of view.root.findAllByType('output')) {
    assert.equal(output.props.loading, false);
    assert.match(output.props.children, /10/);
  }
  await act(async () => { updated.resolve(json([{ balance: 20 }])); });
  for (const output of view.root.findAllByType('output')) assert.match(output.props.children, /20/);
});

test('visible admin pages pick up external changes; hidden pages do not poll', async (t) => {
  const fixture = setup(t);
  t.mock.timers.enable({ apis: ['setInterval'] });
  let balance = 10, reads = 0;
  api.fetchImpl = async () => { reads++; return json([{ balance }]); };
  let view;
  await act(async () => { view = fixture.mount(React.createElement(Probe, { path: '/admin/users' })); });
  balance = 20;
  document.visibilityState = 'hidden';
  await act(async () => { t.mock.timers.tick(30000); });
  assert.equal(reads, 1);
  document.visibilityState = 'visible';
  await act(async () => { t.mock.timers.tick(30000); });
  assert.equal(reads, 2);
  assert.match(view.root.findByType('output').props.children, /20/);
});
