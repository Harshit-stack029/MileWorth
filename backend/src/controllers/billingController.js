const User = require('../models/User');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');
const googlePlay = require('../utils/googlePlay');

/**
 * Verify a Google Play purchase and activate the subscription.
 *
 * SECURITY: the client must never be trusted to declare itself subscribed.
 * Decision order (independent of NODE_ENV, so a misconfigured deployment can't
 * leak free Pro):
 *   1. If Google Play verification is configured, ALWAYS verify the
 *      purchaseToken with the Android Publisher API before granting Pro.
 *   2. Else, if ALLOW_MOCK_BILLING=true (local dev only), mock-activate so the
 *      paywall UX is testable without a Play account.
 *   3. Else, return 501 — Pro is never granted on an unverified claim.
 */
const verify = asyncHandler(async (req, res) => {
  const { purchaseToken, productId } = req.body;

  if (googlePlay.isConfigured()) {
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

  if (env.allowMockBilling) {
    if (!purchaseToken || !productId) {
      return res.status(400).json({ error: 'purchaseToken and productId are required' });
    }
    const user = await User.findById(req.user.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.subscriptionStatus = 'active';
    await user.save();
    return res.json({ user: user.toPublicJSON(), mock: true });
  }

  return res.status(501).json({
    error: 'Subscription verification is not configured yet',
  });
});

module.exports = { verify };
