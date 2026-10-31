import test from 'node:test';
import assert from 'node:assert/strict';
import { csvCell } from '../src/utils/csv.js';
test('CSV quotes untrusted cells and prevents formula injection', () => {
  assert.equal(csvCell('=HYPERLINK("bad")'), '"\'=HYPERLINK(""bad"")"');
  assert.equal(csvCell('normal, value'), '"normal, value"');
  assert.equal(csvCell(null), '""');
});
