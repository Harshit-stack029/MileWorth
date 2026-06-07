const test = require('node:test');
const assert = require('node:assert/strict');
const { autoClassify } = require('../src/utils/autoClassify');

const SATURDAY = '2026-06-06T10:00:00Z'; // Sat
const MONDAY = '2026-06-08T10:00:00Z'; // Mon

test('never overrides an explicit category', () => {
  assert.equal(
    autoClassify({ category: 'business', startTime: SATURDAY, settings: { classifyWeekendsAsPersonal: true } }),
    'business',
  );
});

test('weekend rule tags uncategorized weekend trips as personal', () => {
  assert.equal(
    autoClassify({ category: 'uncategorized', startTime: SATURDAY, settings: { classifyWeekendsAsPersonal: true } }),
    'personal',
  );
});

test('weekend rule leaves weekday trips uncategorized', () => {
  assert.equal(
    autoClassify({ category: 'uncategorized', startTime: MONDAY, settings: { classifyWeekendsAsPersonal: true } }),
    'uncategorized',
  );
});

test('rule disabled leaves weekend trips uncategorized', () => {
  assert.equal(
    autoClassify({ category: 'uncategorized', startTime: SATURDAY, settings: { classifyWeekendsAsPersonal: false } }),
    'uncategorized',
  );
});
