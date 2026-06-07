require('dotenv').config();

function required(name) {
  const value = process.env[name];
  if (!value) {
    // eslint-disable-next-line no-console
    console.warn(`[env] Missing ${name} — set it in backend/.env`);
  }
  return value;
}

module.exports = {
  port: parseInt(process.env.PORT || '4000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: required('MONGODB_URI'),
  jwtSecret: process.env.JWT_SECRET || 'dev-insecure-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '30d',
  defaultMileageRate: parseFloat(process.env.DEFAULT_MILEAGE_RATE || '0.70'),
  defaultCurrency: process.env.DEFAULT_CURRENCY || 'USD',
};
