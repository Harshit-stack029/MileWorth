const nodemailer = require('nodemailer');
const env = require('../config/env');

// Lazily build a single SMTP transport. When SMTP isn't configured (dev/tests),
// `transport` stays null and we log the message instead of sending it, so the
// password-reset / verification flows are fully testable without a mail provider.
let transport = null;
function getTransport() {
  if (transport) return transport;
  const { host, port, user, pass } = env.smtp;
  if (!host || !user || !pass) return null;
  transport = nodemailer.createTransport({
    host,
    port,
    secure: port === 465, // 465 = implicit TLS; 587 upgrades via STARTTLS
    auth: { user, pass },
  });
  return transport;
}

function isConfigured() {
  return Boolean(env.smtp.host && env.smtp.user && env.smtp.pass);
}

/**
 * Send an email. Returns { sent: boolean }. Never throws on a missing transport
 * — when unconfigured it logs to the console so callers don't need to branch.
 */
async function sendMail({ to, subject, text, html }) {
  const tx = getTransport();
  if (!tx) {
    // eslint-disable-next-line no-console
    console.log(`[mailer] (not configured) would send to ${to}: ${subject}\n${text}`);
    return { sent: false };
  }
  await tx.sendMail({ from: env.smtp.from, to, subject, text, html });
  return { sent: true };
}

module.exports = { sendMail, isConfigured };
