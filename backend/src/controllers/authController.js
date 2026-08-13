const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Trip = require('../models/Trip');
const Expense = require('../models/Expense');
const Location = require('../models/Location');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');
const mailer = require('../utils/mailer');
const tokens = require('../utils/authTokens');
const { findUserWithToken, reconcileSubscription } = require('../utils/subscription');

function signToken(user) {
  return jwt.sign({}, env.jwtSecret, {
    subject: user._id.toString(),
    expiresIn: env.jwtExpiresIn,
  });
}

// --- Browser pages for the links we email out (verify / reset) ---------------
// These are opened in a web browser (deep-linking into the app isn't wired yet),
// so they return HTML rather than JSON. The app's own flows still use the JSON
// endpoints; only the emailed links land here.

function escapeAttr(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function htmlPage(title, bodyHtml) {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeAttr(title)} · MileWorth</title>
<style>
  body{font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
       background:#0f1f3d;margin:0;min-height:100vh;display:flex;
       align-items:center;justify-content:center;padding:24px;color:#11223a}
  .card{background:#fff;border-radius:16px;max-width:420px;width:100%;
        padding:32px;box-shadow:0 10px 40px rgba(0,0,0,.25)}
  h1{margin:0 0 8px;font-size:22px}
  p{color:#475569;line-height:1.5}
  .brand{font-weight:800;font-size:18px;margin-bottom:24px}
  .brand span{color:#16a34a}
  label{display:block;font-size:14px;font-weight:600;margin:16px 0 6px}
  input{width:100%;box-sizing:border-box;padding:12px;border:1px solid #cbd5e1;
        border-radius:10px;font-size:16px}
  button{width:100%;margin-top:20px;padding:12px;border:0;border-radius:10px;
         background:#16a34a;color:#fff;font-size:16px;font-weight:700;cursor:pointer}
  .ok{color:#16a34a}.err{color:#dc2626}
</style></head>
<body><div class="card">
  <div class="brand">Mile<span>Worth</span></div>
  ${bodyHtml}
</div></body></html>`;
}

// Send an HTML page. Overrides helmet's global CSP so the inline <style> renders
// while still forbidding any script execution; form-action 'self' lets the reset
// form post back to this backend.
function sendHtmlPage(res, status, title, bodyHtml) {
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'"
  );
  return res.status(status).type('html').send(htmlPage(title, bodyHtml));
}

function resetFormHtml(token, errorHtml = '') {
  return `
    <h1>Choose a new password</h1>
    <p>Enter a new password for your MileWorth account.</p>
    ${errorHtml}
    <form method="POST" action="/auth/reset-password/web">
      <input type="hidden" name="token" value="${escapeAttr(token)}">
      <label for="pw">New password</label>
      <input id="pw" type="password" name="password" minlength="8" required
             autocomplete="new-password" placeholder="At least 8 characters">
      <button type="submit">Set new password</button>
    </form>`;
}

const RESET_LINK_INVALID =
  '<h1>Link not valid</h1><p>This password-reset link is invalid or has '
  + 'expired. Request a new one from the MileWorth app.</p>';

const register = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: 'password must be at least 8 characters' });
  }
  const normalizedEmail = String(email).trim().toLowerCase();
  const existing = await User.findOne({ email: normalizedEmail });
  if (existing) {
    return res.status(409).json({ error: 'An account with that email already exists' });
  }
  const user = new User({ email: normalizedEmail });
  await user.setPassword(password);
  await user.save();
  // The account is already persisted. Verification email is non-blocking (the
  // dashboard soft-gates unverified accounts and offers a resend), so a mail
  // outage must NOT fail the signup — otherwise the client sees a 500, the user
  // already exists, and a retry dead-ends into 409 with no JWT ever returned.
  try {
    await sendVerificationEmail(user);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[auth] verification email failed to send on register:', err.message);
  }
  return res.status(201).json({ token: signToken(user), user: user.toPublicJSON() });
});

// Email a verification link. Shared by register + the resend endpoint.
async function sendVerificationEmail(user) {
  const token = tokens.signEmailVerifyToken(user);
  const link = `${env.appPublicUrl}/auth/verify-email?token=${encodeURIComponent(token)}`;
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
  // The emailed link is a GET; the app posts JSON. Render HTML for the browser
  // and JSON for the app.
  const wantsHtml = req.method === 'GET';
  const fail = (msg) => (wantsHtml
    ? sendHtmlPage(res, 400, 'Email verification',
      `<h1>Link not valid</h1><p>${escapeAttr(msg)}</p>`)
    : res.status(400).json({ error: msg }));
  const ok = (user) => (wantsHtml
    ? sendHtmlPage(res, 200, 'Email verified',
      '<h1 class="ok">Email verified ✓</h1><p>Your email address is confirmed. '
      + 'You can return to the MileWorth app.</p>')
    // The caller proved possession of a validly-signed token, so returning their
    // own user object is safe. Omit it on the already-verified path (see below).
    : res.json(user ? { verified: true, user: user.toPublicJSON() } : { verified: true }));

  if (!token) return fail('token is required');

  const userId = tokens.decodeSubject(token);
  const user = userId ? await User.findById(userId) : null;
  if (!user) return fail('Invalid or expired link');

  // Already verified: the signing secret has since rotated (it folds in the
  // verified flag), so we can't re-verify the signature — and needn't. Return a
  // generic confirmation with NO account data: echoing toPublicJSON() here would
  // leak a victim's email/subscription to anyone forging an unsigned token with
  // their (guessable) id, since decodeSubject does not check the signature.
  if (user.emailVerified) return ok(null);

  try {
    tokens.verifyEmailVerifyToken(token, user);
  } catch (_) {
    return fail('Invalid or expired link');
  }

  user.emailVerified = true;
  await user.save();
  return ok(user);
});

// Browser landing page for the emailed reset link: a form that posts the new
// password to /auth/reset-password/web. The app still uses the JSON endpoint.
const resetPasswordPage = asyncHandler(async (req, res) => {
  const token = String(req.query.token || '');
  if (!token) return sendHtmlPage(res, 400, 'Reset password', RESET_LINK_INVALID);
  return sendHtmlPage(res, 200, 'Reset password', resetFormHtml(token));
});

// Handles the submitted reset form (urlencoded) and renders an HTML result.
// Mirrors resetPassword but returns a page instead of a JWT — the browser just
// needs confirmation; the user then signs in from the app.
const resetPasswordWeb = asyncHandler(async (req, res) => {
  const { token, password } = req.body;
  if (!token) return sendHtmlPage(res, 400, 'Reset password', RESET_LINK_INVALID);
  if (!password || password.length < 8) {
    return sendHtmlPage(res, 400, 'Reset password',
      resetFormHtml(token, '<p class="err">Password must be at least 8 characters.</p>'));
  }

  const userId = tokens.decodeSubject(token);
  const user = userId ? await User.findById(userId) : null;
  if (!user) return sendHtmlPage(res, 400, 'Reset password', RESET_LINK_INVALID);

  try {
    tokens.verifyPasswordResetToken(token, user);
  } catch (_) {
    return sendHtmlPage(res, 400, 'Reset password', RESET_LINK_INVALID);
  }

  await user.setPassword(password);
  await user.save(); // changes passwordHash -> the used reset token is now dead
  return sendHtmlPage(res, 200, 'Password updated',
    '<h1 class="ok">Password updated ✓</h1><p>Your password has been changed. '
    + 'Open the MileWorth app and sign in with your new password.</p>');
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  const user = await User.findOne({ email: String(email).trim().toLowerCase() });
  if (!user || !(await user.verifyPassword(password))) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }
  return res.json({ token: signToken(user), user: user.toPublicJSON() });
});

const me = asyncHandler(async (req, res) => {
  const user = await findUserWithToken(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  // Lapse/renew the subscription if the cached period has ended, so a stale
  // 'active' can't keep granting Pro after the user stops paying.
  const changed = await reconcileSubscription(user);
  if (changed) await user.save();
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

  const user = await User.findOne({ email: String(email).trim().toLowerCase() });
  if (!user) return res.json(generic);

  const token = tokens.signPasswordResetToken(user);
  const link = `${env.appPublicUrl}/auth/reset-password?token=${encodeURIComponent(token)}`;
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
  requestPasswordReset, resetPassword, resetPasswordPage, resetPasswordWeb,
  resendVerification, verifyEmail,
};
