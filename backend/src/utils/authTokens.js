const jwt = require('jsonwebtoken');
const env = require('../config/env');

// Email-flow tokens (password reset, email verification) are short-lived JWTs
// signed with a PER-USER secret derived from mutable account state. This makes
// them effectively single-use with no extra DB collection:
//   - reset tokens fold in the current passwordHash, so once the password
//     changes the old reset link stops working.
//   - verify tokens fold in the verified flag, so the link dies after one use.

function resetSecret(user) {
  return `${env.jwtSecret}:pwreset:${user.passwordHash}`;
}

function verifySecret(user) {
  return `${env.jwtSecret}:verify:${user.email}:${user.emailVerified ? 1 : 0}`;
}

function signPasswordResetToken(user) {
  return jwt.sign({ purpose: 'pwreset' }, resetSecret(user), {
    subject: user._id.toString(),
    expiresIn: env.passwordResetExpiresIn,
  });
}

function signEmailVerifyToken(user) {
  return jwt.sign({ purpose: 'verify' }, verifySecret(user), {
    subject: user._id.toString(),
    expiresIn: env.emailVerifyExpiresIn,
  });
}

// Pull the subject (userId) from a token WITHOUT verifying the signature, so the
// caller can load the user and then verify with that user's derived secret.
function decodeSubject(token) {
  const decoded = jwt.decode(token);
  return decoded && typeof decoded === 'object' ? decoded.sub : null;
}

function verifyPasswordResetToken(token, user) {
  const payload = jwt.verify(token, resetSecret(user));
  if (payload.purpose !== 'pwreset') throw new Error('wrong token purpose');
  return payload;
}

function verifyEmailVerifyToken(token, user) {
  const payload = jwt.verify(token, verifySecret(user));
  if (payload.purpose !== 'verify') throw new Error('wrong token purpose');
  return payload;
}

module.exports = {
  signPasswordResetToken,
  signEmailVerifyToken,
  decodeSubject,
  verifyPasswordResetToken,
  verifyEmailVerifyToken,
};
