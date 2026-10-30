import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import React from 'react';
import TestRenderer, { act } from 'react-test-renderer';
import { createServer } from 'vite';
import react from '@vitejs/plugin-react';

let server, api, ArchiveActions, StoreCoverEditor, Settings, Stores, Users;
before(async () => {
  server = await createServer({ configFile: false, root: fileURLToPath(new URL('../', import.meta.url)),
    plugins: [react()], server: { middlewareMode: true, hmr: false }, appType: 'custom' });
  ({ api } = await server.ssrLoadModule('/src/services/api.js'));
  ({ default: ArchiveActions } = await server.ssrLoadModule('/src/components/ArchiveActions.jsx'));
  ({ default: StoreCoverEditor } = await server.ssrLoadModule('/src/components/StoreCoverEditor.jsx'));
  ({ default: Settings } = await server.ssrLoadModule('/src/pages/Settings.jsx'));
  ({ default: Stores } = await server.ssrLoadModule('/src/pages/Stores.jsx'));
  ({ default: Users } = await server.ssrLoadModule('/src/pages/Users.jsx'));
});
after(async () => { await server?.close(); });

function fixture(t, component, props) {
  const oldWindow = globalThis.window, oldDocument = globalThis.document;
  globalThis.window = { confirm: () => true, location: { host: 'local-admin.test' }, addEventListener() {}, removeEventListener() {} };
  globalThis.document = { visibilityState: 'visible', body: { style: {} }, addEventListener() {}, removeEventListener() {} };
  let view;
  act(() => { view = TestRenderer.create(React.createElement(component, props),
    { createNodeMock: () => ({ value: '' }) }); });
  const unmount = async () => { if (view) { await act(async () => view.unmount()); view = null; } };
  t.after(async () => { await unmount(); globalThis.window = oldWindow; globalThis.document = oldDocument; });
  return { get view() { return view; }, unmount };
}
const clickEvent = { stopPropagation() {} };
const buttonText = (node) => node.children.filter((child) => typeof child === 'string').join('');

test('store actions archive first, restore safely, and expose permanent deletion only for unused archived records', async (t) => {
  const requests = [], changes = [];
  t.mock.method(api, 'request', async (path, options) => { requests.push({ path, method: options.method }); return {}; });
  const record = { id: 'store', name: 'Preview store', can_delete: true };
  const f = fixture(t, ArchiveActions, { kind: 'partners', record, onChanged: (action) => changes.push(action) });
  assert.deepEqual(f.view.root.findAllByType('button').map(buttonText), ['Archive']);
  await act(async () => f.view.root.findByType('button').props.onClick(clickEvent));
  assert.deepEqual(requests, [{ path: '/admin/partners/store/archive', method: 'POST' }]);
  await act(async () => f.view.update(React.createElement(ArchiveActions,
    { kind: 'partners', record: { ...record, archived_at: '2026-10-18', can_delete: false } })));
  assert.deepEqual(f.view.root.findAllByType('button').map(buttonText), ['Restore']);
  await act(async () => f.view.root.findByType('button').props.onClick(clickEvent));
  assert.equal(requests.at(-1).path, '/admin/partners/store/restore');
  await act(async () => f.view.update(React.createElement(ArchiveActions,
    { kind: 'partners', record: { ...record, archived_at: '2026-10-18' } })));
  const remove = f.view.root.findAllByType('button').find((node) => buttonText(node) === 'Delete permanently');
  await act(async () => remove.props.onClick(clickEvent));
  assert.deepEqual(requests.at(-1), { path: '/admin/partners/store', method: 'DELETE' });
  assert.deepEqual(changes, ['archive']);
});

test('failed archive retains the controls and shows the server error', async (t) => {
  t.mock.method(api, 'request', async () => { throw Error('Request could not be saved'); });
  const f = fixture(t, ArchiveActions, { kind: 'offers', record: { id: 'offer', title: 'Preview deal' } });
  await act(async () => f.view.root.findByType('button').props.onClick(clickEvent));
  assert.match(f.view.root.findByProps({ role: 'alert' }).children.join(''), /could not be saved/);
  assert.equal(f.view.root.findByType('button').props.disabled, false);
});

test('cover selection previews the image, uploads the selected file, and releases its object URL', async (t) => {
  const revoked = [], saved = [], uploaded = [];
  t.mock.method(URL, 'createObjectURL', () => 'blob:local-cover-preview');
  t.mock.method(URL, 'revokeObjectURL', (url) => revoked.push(url));
  t.mock.method(api, 'uploadPartnerCover', async (id, file) => {
    uploaded.push({ id, file }); return { cover_image_url: 'https://api.stepsyapp.com/media/store-covers/new.webp' };
  });
  const f = fixture(t, StoreCoverEditor, { store: { id: 'store', name: 'Preview store' }, onSaved: (url) => saved.push(url) });
  const file = new File(['fixture'], 'cover.png', { type: 'image/png' });
  await act(async () => f.view.root.findByType('input').props.onChange({ target: { files: [file] } }));
  assert.equal(f.view.root.findByType('img').props.src, 'blob:local-cover-preview');
  const save = f.view.root.findAllByType('button').find((node) => buttonText(node) === 'Save cover');
  assert.equal(save.props.disabled, false);
  await act(async () => save.props.onClick());
  assert.deepEqual(uploaded, [{ id: 'store', file }]);
  assert.equal(saved.length, 1);
  assert.deepEqual(revoked, ['blob:local-cover-preview']);
  assert.match(f.view.root.findByProps({ role: 'status' }).children.join(''), /Cover saved/);
});

test('unsupported or oversized covers never enable uploading', async (t) => {
  const f = fixture(t, StoreCoverEditor, { store: { id: 'store' }, onSaved() {} });
  for (const file of [new File(['<svg/>'], 'cover.svg', { type: 'image/svg+xml' }),
    new File([new Uint8Array(4 * 1024 * 1024 + 1)], 'cover.png', { type: 'image/png' })]) {
    await act(async () => f.view.root.findByType('input').props.onChange({ target: { files: [file] } }));
    assert.match(f.view.root.findByProps({ role: 'alert' }).children.join(''), /4 MB/);
    assert.equal(f.view.root.findByType('button').props.disabled, true);
  }
});

test('Settings sign-out invokes the same authenticated client as the navbar', async (t) => {
  let logouts = 0;
  t.mock.method(api, 'logout', () => logouts++);
  t.mock.method(api, 'request', async () => ({ environment: 'test', steps_per_point: 100, daily_step_cap: 20000, voucher_validity_days: 30 }));
  const f = fixture(t, Settings, { user: { email: 'admin@example.com' } });
  await act(async () => {});
  const logout = f.view.root.findAllByType('button').find((node) => buttonText(node).includes('Sign Out'));
  await act(async () => logout.props.onClick());
  assert.equal(logouts, 1);
});

test('new stores can explicitly link an existing account without submitting a password', async (t) => {
  const writes = [];
  t.mock.method(api, 'request', async () => []);
  t.mock.method(api, 'createPartner', async (body) => { writes.push(body); return { id: 'new-store', email: body.email, name: body.name }; });
  const f = fixture(t, Stores, {});
  await act(async () => {});
  const register = f.view.root.findAllByType('button').find((node) => node.findAllByType('span').some((label) => label.children.includes('Register New Store')));
  await act(async () => register.props.onClick());
  await act(async () => f.view.root.findByProps({ type: 'checkbox' }).props.onChange({ target: { checked: true } }));
  assert.equal(f.view.root.findAllByProps({ type: 'password' }).length, 0);
  const name = f.view.root.findAllByType('input').find((node) => node.props.placeholder?.includes('Apex Cafe'));
  await act(async () => name.props.onChange({ target: { value: 'Linked test store' } }));
  await act(async () => f.view.root.findByProps({ type: 'email' }).props.onChange({ target: { value: 'merchant@example.com' } }));
  await act(async () => f.view.root.findByType('form').props.onSubmit({ preventDefault() {} }));
  assert.equal(writes.length, 1);
  assert.equal(writes[0].use_existing_account, true);
  assert.equal(writes[0].password, undefined);
  assert.equal(writes[0].email, 'merchant@example.com');
  assert.match(JSON.stringify(f.view.toJSON()), /existing password and Google sign-in are kept/);
});

test('user editor prevents granting an unlinked merchant role', async (t) => {
  t.mock.method(api, 'request', async () => [{ id: 'customer', email: 'customer@example.com', role: 'USER', partner_id: null, status: 'ACTIVE', total_steps: 0, points_balance: 0 }]);
  const f = fixture(t, Users, {});
  await act(async () => {});
  const edit = f.view.root.findByProps({ title: 'Edit User' });
  await act(async () => edit.props.onClick());
  assert.equal(f.view.root.findByProps({ value: 'MERCHANT' }).props.disabled, true);
});
