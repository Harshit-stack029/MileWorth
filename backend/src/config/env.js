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

function resolveJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (secret) return secret;
  // A missing secret in production means every token is signed with a public,
  // guessable string — anyone could forge a token for any user. Fail loudly.
  if (nodeEnv === 'production') {
    throw new Error('[env] JWT_SECRET is required in production — refusing to start with an insecure default');
  }
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
};
