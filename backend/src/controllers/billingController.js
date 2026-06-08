const User = require('../models/User');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');
const googlePlay = require('../utils/googlePlay');

/**
 * Verify a Google Play purchase and activate the subscription.
 *
 * SECURITY: the client must never be trusted to declare itself subscribed.
 * In production we confirm the purchaseToken with the Google Play Developer API
 * (purchases.subscriptionsv2) via a service account before flipping the status.
 * That integration is OFF until GOOGLE_SERVICE_ACCOUNT_JSON is configured — when
 * absent we return 501 so Pro is never granted on an unverified claim.
 *
 * In non-production we allow a mock activation so the paywall/UX can be tested
 * end-to-end without a Play account.
 */
const verify = asyncHandler(async (req, res) => {
  const { purchaseToken, productId } = req.body;

  if (env.nodeEnv === 'production') {
    if (!googlePlay.isConfigured()) {
      return res.status(501).json({
        error: 'Subscription verification is not configured yet',
      });
    }
    if (!purchaseToken || !productId) {
      return res.status(400).json({ error: 'purchaseToken and productId are required' });
    }
    let result;
    try {
      result = await googlePlay.verifySubscription({ purchaseToken, productId });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[billing] Google Play verification failed:', err.message);
      return res.status(502).json({ error: 'Could not verify the purchase with Google Play' });
    }
    if (!result.active) {
      return res.status(402).json({ error: 'Purchase is not active', state: result.state });
    }
    const user = await User.findById(req.user.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.subscriptionStatus = 'active';
    await user.save();
    return res.json({ user: user.toPublicJSON() });
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
