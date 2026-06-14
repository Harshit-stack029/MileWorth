require('dotenv').config();

function required(name) {
  const value = process.env[name];
  if (!value) {
    // eslint-disable-next-line no-console
    console.warn(`[env] Missing ${name} — set it in backend/.env`);
  }
  return value;
}

const nodeEnv = process.env.NODE_ENV || 'development';

// Placeholder/example values that must never reach production — a guessable
// signing secret lets anyone forge a token for any user.
const WEAK_SECRETS = new Set([
  'change-me-to-a-long-random-string',
  'dev-insecure-secret',
  'secret',
  'changeme',
  'password',
]);

function resolveJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (nodeEnv === 'production') {
    // Fail loudly rather than start with a forgeable token signer.
    if (!secret) {
      throw new Error('[env] JWT_SECRET is required in production — refusing to start with an insecure default');
    }
    if (secret.length < 16 || WEAK_SECRETS.has(secret)) {
      throw new Error('[env] JWT_SECRET is too weak/placeholder for production — set a long random value');
    }
    return secret;
  }
  if (secret) return secret;
  console.warn('[env] JWT_SECRET not set — using an insecure development-only secret');
  return 'dev-insecure-secret';
}

module.exports = {
  port: parseInt(process.env.PORT || '4000', 10),
  nodeEnv,
  mongoUri: required('MONGODB_URI'),
  jwtSecret: resolveJwtSecret(),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '30d',
  defaultMileageRate: parseFloat(process.env.DEFAULT_MILEAGE_RATE || '0.70'),
  defaultCurrency: process.env.DEFAULT_CURRENCY || 'USD',
  // Google Play subscription verification (optional; off until configured).
  googleServiceAccountJson: process.env.GOOGLE_SERVICE_ACCOUNT_JSON,
  androidPackageName: process.env.ANDROID_PACKAGE_NAME || 'com.mileworth.app',
  // Mock billing (grant Pro WITHOUT verifying a purchase) is for local UX
  // testing only. It requires an explicit opt-in flag rather than keying off
  // NODE_ENV, so a misconfigured deployment can never hand out free Pro.
  allowMockBilling: process.env.ALLOW_MOCK_BILLING === 'true',
  // Outbound email (password reset, verification). SMTP is optional: when
  // unset, emails are logged to the server console instead of sent, so dev and
  // tests work without a mail provider.
  smtp: {
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
    from: process.env.MAIL_FROM || 'MileWorth <no-reply@mileworth.app>',
  },
  // Short-lived token lifetimes for email flows.
  passwordResetExpiresIn: process.env.PASSWORD_RESET_EXPIRES_IN || '1h',
  emailVerifyExpiresIn: process.env.EMAIL_VERIFY_EXPIRES_IN || '2d',
  // Deep-link / web base used in the links we email out.
  appPublicUrl: process.env.APP_PUBLIC_URL || 'https://mileworth-api.onrender.com',
};
