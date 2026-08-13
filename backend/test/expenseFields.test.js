const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validatePaymentMethod,
  validateDefaultedFields,
  PAYMENT_METHODS,
} = require('../src/controllers/expenseController');

test('accepts an absent paymentMethod so the schema default applies', () => {
  assert.equal(validatePaymentMethod(undefined), null);
  assert.equal(validatePaymentMethod(null), null);
});

test('accepts every method in the model enum', () => {
  for (const method of PAYMENT_METHODS) {
    assert.equal(validatePaymentMethod(method), null);
  }
});

test('rejects an unknown paymentMethod and names the valid ones', () => {
  const error = validatePaymentMethod('crypto');
  assert.match(error, /must be one of/);
  for (const method of PAYMENT_METHODS) {
    assert.ok(error.includes(method), `error should list "${method}"`);
  }
});

test('rejects a non-string paymentMethod', () => {
  assert.match(validatePaymentMethod(7), /must be one of/);
});

test('allows a body that omits the defaulted fields entirely', () => {
  assert.equal(validateDefaultedFields({ date: '2026-01-01', amount: 12 }), null);
});

test('allows explicit non-null values for the defaulted fields', () => {
  assert.equal(
    validateDefaultedFields({ currency: 'EUR', paymentMethod: 'card', isDeductible: false }),
    null,
  );
});

test('rejects an explicit null on each defaulted field', () => {
  for (const field of ['currency', 'paymentMethod', 'isDeductible']) {
    const error = validateDefaultedFields({ [field]: null });
    assert.match(error, /may not be null/);
    assert.ok(error.startsWith(field), `error should name "${field}"`);
  }
});

test('isDeductible: false is kept — it must not be confused with null', () => {
  // A false value is a legitimate "not deductible", so the null guard has to
  // compare identity rather than truthiness.
  assert.equal(validateDefaultedFields({ isDeductible: false }), null);
});
