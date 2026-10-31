import test from 'node:test';
import assert from 'node:assert/strict';
import { googleMapsLink, apiErrorMessage } from '../src/services/store-location.js';

test('admin links accept real Google Maps place/share formats', () => {
  for (const link of ['https://maps.app.goo.gl/abc', 'https://maps.google.com/?q=Lahore',
    'https://www.google.com/maps/place/Lahore', 'https://goo.gl/maps/abc']) {
    assert.equal(googleMapsLink(` ${link} `), link);
  }
});
test('legacy unsafe admin links have no clickable external destination', () => {
  for (const link of ['javascript:alert(1)', 'https://google.com.evil.example/maps',
    'https://www.google.com/search?q=test', 'https://evil@maps.google.com/maps',
    'http://maps.google.com/maps', 'https://maps.google.com:443/maps', '', null]) {
    assert.equal(googleMapsLink(link), null);
  }
});
test('Pydantic validation errors produce useful form feedback', () => {
  assert.equal(apiErrorMessage({ detail: [{ msg: 'Use an HTTPS Google Maps link.' }] }, 422), 'Use an HTTPS Google Maps link.');
  assert.equal(apiErrorMessage({ detail: 'Store unavailable' }, 409), 'Store unavailable');
  assert.equal(apiErrorMessage({}, 503), 'Request failed with status 503');
});
