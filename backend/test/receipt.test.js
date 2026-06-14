const test = require('node:test');
const assert = require('node:assert/strict');
const { validateReceipt, MAX_RECEIPT_CHARS } = require('../src/controllers/expenseController');

test('accepts a null/absent receipt', () => {
  assert.equal(validateReceipt(undefined), null);
  assert.equal(validateReceipt(null), null);
});

test('accepts a jpeg/png data URL and an http URL', () => {
  assert.equal(validateReceipt('data:image/jpeg;base64,/9j/4AAQ'), null);
  assert.equal(validateReceipt('data:image/png;base64,iVBORw0KGgo'), null);
  assert.equal(validateReceipt('https://cdn.example.com/r/1.jpg'), null);
});

test('rejects a non-image data URL', () => {
  assert.match(
    validateReceipt('data:application/pdf;base64,JVBERi0x'),
    /image data URL or http/,
  );
});

test('rejects a non-string', () => {
  assert.match(validateReceipt(42), /must be a string/);
});

test('rejects an oversized receipt with the "too large" message', () => {
  const huge = `data:image/jpeg;base64,${'A'.repeat(MAX_RECEIPT_CHARS)}`;
  assert.match(validateReceipt(huge), /too large/);
});
