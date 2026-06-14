const test = require('node:test');
const assert = require('node:assert/strict');
const tokens = require('../src/utils/authTokens');

// Minimal user stand-ins (only the fields the token helpers read).
function makeUser(overrides = {}) {
  return {
    _id: { toString: () => '64b000000000000000000001' },
    email: 'a@b.com',
    passwordHash: 'hash-v1',
    emailVerified: false,
    ...overrides,
  };
}

test('a fresh reset token verifies for the same user', () => {
  const user = makeUser();
  const token = tokens.signPasswordResetToken(user);
  assert.equal(tokens.decodeSubject(token), '64b000000000000000000001');
  assert.doesNotThrow(() => tokens.verifyPasswordResetToken(token, user));
});

test('a reset token dies once the password hash changes', () => {
  const user = makeUser();
  const token = tokens.signPasswordResetToken(user);
  const afterReset = makeUser({ passwordHash: 'hash-v2' });
  assert.throws(() => tokens.verifyPasswordResetToken(token, afterReset));
});

test('a verify token dies once the account is verified', () => {
  const user = makeUser();
  const token = tokens.signEmailVerifyToken(user);
  assert.doesNotThrow(() => tokens.verifyEmailVerifyToken(token, user));
  const verified = makeUser({ emailVerified: true });
  assert.throws(() => tokens.verifyEmailVerifyToken(token, verified));
});

test('a reset token is rejected by the verify path (purpose mismatch)', () => {
  const user = makeUser();
  const resetToken = tokens.signPasswordResetToken(user);
  assert.throws(() => tokens.verifyEmailVerifyToken(resetToken, user));
});
