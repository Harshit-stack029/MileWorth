const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const env = require('./config/env');
const { errorHandler, notFound } = require('./middleware/error');

const app = express();

// Render (and most PaaS) put the app behind a reverse proxy, so the real client
// IP arrives in X-Forwarded-For. Trust one proxy hop so rate limiting keys on
// the actual caller rather than the proxy's IP.
app.set('trust proxy', 1);

app.use(helmet());
app.use(cors());
// Body limit must comfortably exceed the max receipt data-URL (≈1.9MB of
// base64) so large receipts hit the controller's friendly 413 instead of a
// confusing low-level parser error. Keep in sync with MAX_RECEIPT_CHARS.
app.use(express.json({ limit: '3mb' }));
// The emailed password-reset form posts urlencoded; everything else is JSON.
app.use(express.urlencoded({ extended: false }));
if (env.nodeEnv !== 'test') app.use(morgan('dev'));

// Health + deployment self-check. `env` and the *_configured booleans let you
// confirm a deployment is correct without exposing any secret values.
app.get('/health', (req, res) => res.json({
  status: 'ok',
  service: 'mileworth-api',
  env: env.nodeEnv,
  billingConfigured: require('./utils/googlePlay').isConfigured(),
  mockBilling: env.allowMockBilling,
  emailConfigured: require('./utils/mailer').isConfigured(),
}));

app.use('/auth', require('./routes/auth'));
app.use('/trips', require('./routes/trips'));
app.use('/locations', require('./routes/locations'));
app.use('/expenses', require('./routes/expenses'));
app.use('/reports', require('./routes/reports'));
app.use('/billing', require('./routes/billing'));

app.use(notFound);
app.use(errorHandler);

module.exports = app;
