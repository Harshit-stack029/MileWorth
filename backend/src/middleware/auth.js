const jwt = require('jsonwebtoken');
const env = require('../config/env');

// Verifies the Bearer JWT and attaches { userId } to req.user.
module.exports = function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'Missing or malformed Authorization header' });
  }
  try {
    const payload = jwt.verify(token, env.jwtSecret);
    req.user = { userId: payload.sub };
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};
