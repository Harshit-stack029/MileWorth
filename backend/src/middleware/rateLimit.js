const rateLimit = require('express-rate-limit');

const env = require('../config/env');

// Throttle auth endpoints to blunt brute-force password guessing and signup spam.
// Disabled in tests so the suite isn't tripped by repeated requests.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: env.nodeEnv === 'test' ? 0 : 10, // 10 attempts per IP per window (0 = disabled)
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => env.nodeEnv === 'test',
  message: { error: 'Too many attempts. Please try again in a few minutes.' },
});

module.exports = { authLimiter };
