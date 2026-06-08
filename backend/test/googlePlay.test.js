const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const { buildAssertion } = require('../src/utils/googlePlay');

// Verifies the OAuth assertion is a well-formed RS256 JWT with the claims the
// Google token endpoint expects. Runs offline — no network, no real credentials.
test('buildAssertion mints a valid RS256 JWT for the publisher scope', () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const account = {
    client_email: 'svc@project.iam.gserviceaccount.com',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  };

  const token = buildAssertion(account, 1000);
  const decoded = jwt.verify(
    token,
    publicKey.export({ type: 'spki', format: 'pem' }),
    { algorithms: ['RS256'], ignoreExpiration: true },
  );

  assert.equal(decoded.iss, account.client_email);
  assert.equal(decoded.aud, 'https://oauth2.googleapis.com/token');
  assert.equal(decoded.scope, 'https://www.googleapis.com/auth/androidpublisher');
  assert.equal(decoded.iat, 1000);
  assert.equal(decoded.exp, 1000 + 3600);
});

test('buildAssertion rejects a wrong verification key', () => {
  const { privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  const { publicKey: otherPublic } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const account = {
    client_email: 'svc@project.iam.gserviceaccount.com',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  };
  const token = buildAssertion(account, 1000);
  assert.throws(() =>
    jwt.verify(token, otherPublic.export({ type: 'spki', format: 'pem' }), {
      algorithms: ['RS256'],
    }),
  );
});
