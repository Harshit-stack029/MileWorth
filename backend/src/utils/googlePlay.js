const https = require('https');
const jwt = require('jsonwebtoken');
const env = require('./../config/env');

// Google Play subscription verification using the Android Publisher API
// (purchases.subscriptionsv2). Implemented with built-ins + jsonwebtoken so it
// adds no dependencies. It is OFF until a service account is configured, so the
// production default behaviour (501 "not configured") is unchanged.
//
// To enable, set in the backend environment:
//   GOOGLE_SERVICE_ACCOUNT_JSON = the full service-account JSON (one line)
//   ANDROID_PACKAGE_NAME        = com.mileworth.app  (defaulted)
// The service account needs the Android Publisher API enabled and be granted
// "View financial data" access in Play Console.

let serviceAccount = null;
let parseError = null;
if (env.googleServiceAccountJson) {
  try {
    serviceAccount = JSON.parse(env.googleServiceAccountJson);
  } catch (e) {
    parseError = e.message;
    // Surface it loudly — otherwise a malformed paste silently disables billing
    // (isConfigured() returns false → every purchase gets a confusing 501).
    // eslint-disable-next-line no-console
    console.error(`[googlePlay] GOOGLE_SERVICE_ACCOUNT_JSON could not be parsed: ${e.message}`);
  }
}

function isConfigured() {
  return Boolean(serviceAccount && serviceAccount.client_email
    && serviceAccount.private_key && env.androidPackageName);
}

function configError() {
  return parseError;
}

// Build the signed OAuth2 assertion (a JWT) the token endpoint exchanges for an
// access token. Pure + parameterised so it can be unit-tested offline.
function buildAssertion(account, now) {
  return jwt.sign(
    {
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    account.private_key,
    { algorithm: 'RS256' },
  );
}

function httpsRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve({ statusCode: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.setTimeout(15000, () => req.destroy(new Error('Google Play request timed out')));
    if (body) req.write(body);
    req.end();
  });
}

async function getAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const assertion = buildAssertion(serviceAccount, now);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  }).toString();
  const res = await httpsRequest(
    {
      method: 'POST',
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    },
    body,
  );
  const json = JSON.parse(res.body);
  if (!json.access_token) {
    throw new Error(`OAuth error: ${json.error_description || json.error || res.body}`);
  }
  return json.access_token;
}

// Returns { active, state, raw }. `active` is true for an ACTIVE subscription
// (grace period also counts as still-entitled).
async function verifySubscription({ purchaseToken }) {
  const accessToken = await getAccessToken();
  const pkg = env.androidPackageName;
  const path = `/androidpublisher/v3/applications/${encodeURIComponent(pkg)}`
    + `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const res = await httpsRequest({
    method: 'GET',
    hostname: 'androidpublisher.googleapis.com',
    path,
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (res.statusCode !== 200) {
    throw new Error(`Android Publisher API ${res.statusCode}: ${res.body}`);
  }
  const data = JSON.parse(res.body);
  const state = data.subscriptionState;
  const active = state === 'SUBSCRIPTION_STATE_ACTIVE'
    || state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD';
  return { active, state, raw: data };
}

module.exports = { isConfigured, configError, buildAssertion, verifySubscription };
