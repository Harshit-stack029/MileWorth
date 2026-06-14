const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Trip = require('../models/Trip');
const Expense = require('../models/Expense');
const Location = require('../models/Location');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');
const mailer = require('../utils/mailer');
const tokens = require('../utils/authTokens');

function signToken(user) {
  return jwt.sign({}, env.jwtSecret, {
    subject: user._id.toString(),
    expiresIn: env.jwtExpiresIn,
  });
}

const register = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: 'password must be at least 8 characters' });
  }
  const existing = await User.findOne({ email: email.toLowerCase() });
  if (existing) {
    return res.status(409).json({ error: 'An account with that email already exists' });
  }
  const user = new User({ email });
  await user.setPassword(password);
  await user.save();
  await sendVerificationEmail(user);
  return res.status(201).json({ token: signToken(user), user: user.toPublicJSON() });
});

// Email a verification link. Shared by register + the resend endpoint.
async function sendVerificationEmail(user) {
  const token = tokens.signEmailVerifyToken(user);
  const link = `${env.appPublicUrl}/verify-email?token=${encodeURIComponent(token)}`;
  await mailer.sendMail({
    to: user.email,
    subject: 'Confirm your MileWorth email',
    text: `Welcome to MileWorth! Confirm your email address:\n\n${link}\n\n`
      + `This link is valid for 2 days.`,
  });
  return token;
}

// Re-send the verification email for the signed-in user.
const resendVerification = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  if (user.emailVerified) return res.json({ alreadyVerified: true });
  const token = await sendVerificationEmail(user);
  if (env.nodeEnv !== 'production') return res.json({ sent: true, devToken: token });
  return res.json({ sent: true });
});

// Confirm an email-verification token. Accepts the token from the JSON body
// (app) or the query string (the emailed link).
const verifyEmail = asyncHandler(async (req, res) => {
  const token = req.body.token || req.query.token;
  if (!token) return res.status(400).json({ error: 'token is required' });

  const userId = tokens.decodeSubject(token);
  const user = userId ? await User.findById(userId) : null;
  if (!user) return res.status(400).json({ error: 'Invalid or expired link' });

  if (user.emailVerified) return res.json({ user: user.toPublicJSON() });

  try {
    tokens.verifyEmailVerifyToken(token, user);
  } catch (_) {
    return res.status(400).json({ error: 'Invalid or expired link' });
  }

  user.emailVerified = true;
  await user.save();
  return res.json({ user: user.toPublicJSON() });
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  const user = await User.findOne({ email: email.toLowerCase() });
  if (!user || !(await user.verifyPassword(password))) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }
  return res.json({ token: signToken(user), user: user.toPublicJSON() });
});

const me = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  return res.json({ user: user.toPublicJSON() });
});

const updateSettings = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  const { mileageRate, currency, classifyWeekendsAsPersonal } = req.body;
  if (mileageRate != null) {
    const rate = Number(mileageRate);
    if (!Number.isFinite(rate) || rate <= 0) {
      return res.status(400).json({ error: 'mileageRate must be a positive number' });
    }
    user.mileageRate = rate;
  }
  if (currency != null) user.currency = currency;
  if (classifyWeekendsAsPersonal != null) {
    user.classifyWeekendsAsPersonal = classifyWeekendsAsPersonal;
  }
  await user.save();
  return res.json({ user: user.toPublicJSON() });
});

// --- Password reset ---

// Step 1: user submits their email. We ALWAYS return 200 with the same message
// (whether or not the account exists) so this endpoint can't be used to probe
// which emails are registered. When the account exists we email a reset link.
const requestPasswordReset = asyncHandler(async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email is required' });

  const generic = {
    message: 'If an account exists for that email, a reset link is on its way.',
  };

  const user = await User.findOne({ email: String(email).toLowerCase() });
  if (!user) return res.json(generic);

  const token = tokens.signPasswordResetToken(user);
  const link = `${env.appPublicUrl}/reset-password?token=${encodeURIComponent(token)}`;
  await mailer.sendMail({
    to: user.email,
    subject: 'Reset your MileWorth password',
    text: `Tap to reset your password (valid for 1 hour):\n\n${link}\n\n`
      + `If you didn't request this, you can ignore this email.`,
  });

  // Outside production we return the token so the flow is testable without SMTP.
  if (env.nodeEnv !== 'production') return res.json({ ...generic, devToken: token });
  return res.json(generic);
});

// Step 2: user submits the token + new password.
const resetPassword = asyncHandler(async (req, res) => {
  const { token, password } = req.body;
  if (!token || !password) {
    return res.status(400).json({ error: 'token and password are required' });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: 'password must be at least 8 characters' });
  }

  const userId = tokens.decodeSubject(token);
  const user = userId ? await User.findById(userId) : null;
  if (!user) return res.status(400).json({ error: 'Invalid or expired reset link' });

  try {
    tokens.verifyPasswordResetToken(token, user);
  } catch (_) {
    return res.status(400).json({ error: 'Invalid or expired reset link' });
  }

  await user.setPassword(password);
  await user.save(); // changes passwordHash -> the used reset token is now dead
  return res.json({ token: signToken(user), user: user.toPublicJSON() });
});

// Permanently delete the account and ALL associated data. Required by the
// Google Play "account deletion" policy and by GDPR/CCPA erasure rights.
// Cascades to trips, expenses and locations so no orphaned PII is left behind.
const deleteAccount = asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const user = await User.findById(userId);
  if (!user) return res.status(404).json({ error: 'User not found' });

  await Promise.all([
    Trip.deleteMany({ userId }),
    Expense.deleteMany({ userId }),
    Location.deleteMany({ userId }),
  ]);
  await User.deleteOne({ _id: userId });

  return res.status(204).end();
});

module.exports = {
  register, login, me, updateSettings, deleteAccount,
  requestPasswordReset, resetPassword,
  resendVerification, verifyEmail,
};
