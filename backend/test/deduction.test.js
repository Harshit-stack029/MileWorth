const test = require('node:test');
const assert = require('node:assert/strict');
const { computeDeduction } = require('../src/utils/deduction');

test('business trip computes miles * rate', () => {
  assert.equal(computeDeduction({ distance: 100, category: 'business', mileageRate: 0.7 }), 70);
});

test('personal trip has no deduction', () => {
  assert.equal(computeDeduction({ distance: 100, category: 'personal', mileageRate: 0.7 }), 0);
});

test('uncategorized trip has no deduction', () => {
  assert.equal(computeDeduction({ distance: 100, category: 'uncategorized', mileageRate: 0.7 }), 0);
});

test('rounds to cents', () => {
  assert.equal(computeDeduction({ distance: 33.333, category: 'business', mileageRate: 0.7 }), 23.33);
});

test('zero distance is zero', () => {
  assert.equal(computeDeduction({ distance: 0, category: 'business', mileageRate: 0.7 }), 0);
});

test('honors a different rate (e.g. another country/year)', () => {
  assert.equal(computeDeduction({ distance: 50, category: 'business', mileageRate: 0.3 }), 15);
});
