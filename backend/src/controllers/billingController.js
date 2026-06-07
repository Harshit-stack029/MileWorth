const User = require('../models/User');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');

/**
 * Verify a Google Play purchase and activate the subscription.
 *
 * SECURITY: the client must never be trusted to declare itself subscribed.
 * In production this must call the Google Play Developer API
 * (purchases.subscriptionsv2.get) with a service account to confirm the
 * purchaseToken before flipping the status. Until those credentials are wired,
 * production returns 501 so we never grant Pro on an unverified claim.
 *
 * In non-production we allow a mock activation so the paywall/UX can be tested
 * end-to-end without a Play account.
 */
const verify = asyncHandler(async (req, res) => {
  const { purchaseToken, productId } = req.body;

  if (env.nodeEnv === 'production') {
    // TODO: verify purchaseToken with Google Play Developer API, then activate.
    return res.status(501).json({
      error: 'Subscription verification is not configured yet',
    });
  }

  if (!purchaseToken || !productId) {
    return res.status(400).json({ error: 'purchaseToken and productId are required' });
  }

  const user = await User.findById(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  user.subscriptionStatus = 'active';
  await user.save();
  return res.json({ user: user.toPublicJSON(), mock: true });
});

module.exports = { verify };
