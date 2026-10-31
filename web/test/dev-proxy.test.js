import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { createServer } from 'vite';
import config from '../vite.config.js';

test('admin development defaults to localhost and an override reaches only its local API', async () => {
  const previous = process.env.VITE_PROXY_TARGET;
  let vite;
  const backend = http.createServer((request, response) => {
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify({ local: true, path: request.url }));
  });
  try {
    process.env.VITE_PROXY_TARGET = '';
    assert.equal(config({ mode: 'test' }).server.proxy['/admin'].target, 'http://127.0.0.1:8000');
    backend.listen(0, '127.0.0.1');
    await once(backend, 'listening');
    process.env.VITE_PROXY_TARGET = `http://127.0.0.1:${backend.address().port}`;
    vite = await createServer({
      configFile: fileURLToPath(new URL('../vite.config.js', import.meta.url)),
      mode: 'test',
      server: { host: '127.0.0.1', port: 0, strictPort: true },
      logLevel: 'error',
    });
    await vite.listen();
    const result = await fetch(`http://127.0.0.1:${vite.httpServer.address().port}/admin/setup-probe`);
    assert.equal(result.status, 200);
    assert.deepEqual(await result.json(), { local: true, path: '/admin/setup-probe' });
  } finally {
    if (vite) await vite.close();
    if (backend.listening) await new Promise(resolve => backend.close(resolve));
    if (previous === undefined) delete process.env.VITE_PROXY_TARGET;
    else process.env.VITE_PROXY_TARGET = previous;
  }
});
