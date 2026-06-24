const test = require('node:test');
const assert = require('node:assert/strict');
const { isEntitled, latestExpiryMs } = require('../src/utils/googlePlay');
const { reconcileSubscription } = require('../src/utils/subscription');
const User = require('../src/models/User');

const HOUR = 60 * 60 * 1000;

// --- Pure entitlement decision (googlePlay.isEntitled) ---

test('ACTIVE and grace-period subscriptions are entitled', () => {
  const now = 1_000_000;
  assert.equal(isEntitled('SUBSCRIPTION_STATE_ACTIVE', now + HOUR, now), true);
  assert.equal(isEntitled('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', null, now), true);
});

test('a canceled subscription stays entitled until its paid period ends', () => {
  const now = 1_000_000;
  assert.equal(isEntitled('SUBSCRIPTION_STATE_CANCELED', now + HOUR, now), true);
  assert.equal(isEntitled('SUBSCRIPTION_STATE_CANCELED', now - HOUR, now), false);
  assert.equal(isEntitled('SUBSCRIPTION_STATE_CANCELED', null, now), false);
});

test('expired / on-hold / paused revoke entitlement', () => {
  const now = 1_000_000;
  for (const state of [
    'SUBSCRIPTION_STATE_EXPIRED',
    'SUBSCRIPTION_STATE_ON_HOLD',
    'SUBSCRIPTION_STATE_PAUSED',
  ]) {
    assert.equal(isEntitled(state, now + HOUR, now), false);
  }
});

test('latestExpiryMs picks the furthest line-item expiry, or null', () => {
  assert.equal(latestExpiryMs({}), null);
  assert.equal(
    latestExpiryMs({
      lineItems: [
        { expiryTime: '2026-01-01T00:00:00Z' },
        { expiryTime: '2026-03-01T00:00:00Z' },
      ],
    }),
    Date.parse('2026-03-01T00:00:00Z'),
  );
});

// --- reconcileSubscription (the lapse path; uses real model instance methods,
//     no DB needed since save() is the caller's job) ---

test('reconcile leaves an active, still-unexpired subscription unchanged', async () => {
  const user = new User({
    email: 'a@b.com',
    passwordHash: 'x',
    subscriptionStatus: 'active',
    subscriptionExpiry: new Date(Date.now() + 30 * 24 * HOUR),
  });
  const changed = await reconcileSubscription(user);
  assert.equal(changed, false);
  assert.equal(user.subscriptionStatus, 'active');
});

test('reconcile lapses an expired mock subscription (no token to re-verify)', async () => {
  const user = new User({
    email: 'a@b.com',
    passwordHash: 'x',
    subscriptionStatus: 'active',
    subscriptionExpiry: new Date(Date.now() - HOUR),
  });
  const changed = await reconcileSubscription(user);
  assert.equal(changed, true);
  assert.equal(user.subscriptionStatus, 'cancelled');
  assert.equal(user.subscriptionExpiry, undefined);
});

test('reconcile is a no-op for a free user', async () => {
  const user = new User({ email: 'a@b.com', passwordHash: 'x' });
  const changed = await reconcileSubscription(user);
  assert.equal(changed, false);
  assert.equal(user.subscriptionStatus, 'free');
});
