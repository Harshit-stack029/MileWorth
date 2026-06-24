const User = require('../models/User');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');
const googlePlay = require('../utils/googlePlay');
const { findUserWithToken, reconcileSubscription } = require('../utils/subscription');

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
    if (!result.entitled) {
      return res.status(402).json({ error: 'Purchase is not active', state: result.state });
    }
    const user = await findUserWithToken(req.user.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    user.recordSubscription({
      entitled: true, expiryMs: result.expiryMs, purchaseToken, productId,
    });
    await user.save();
    return res.json({ user: user.toPublicJSON() });
  }

  if (env.allowMockBilling) {
    if (!purchaseToken || !productId) {
      return res.status(400).json({ error: 'purchaseToken and productId are required' });
    }
    const user = await User.findById(req.user.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    // Mock period so the lapse path is exercisable in dev: expire in 30 days.
    user.recordSubscription({
      entitled: true,
      expiryMs: Date.now() + 30 * 24 * 60 * 60 * 1000,
      purchaseToken: undefined, // no real token to re-verify against
      productId,
    });
    await user.save();
    return res.json({ user: user.toPublicJSON(), mock: true });
  }

  return res.status(501).json({
    error: 'Subscription verification is not configured yet',
  });
});

/**
 * Re-verify the current subscription and return the (possibly downgraded) user.
 * The app calls this on launch / restore so cancellations and lapses are
 * reflected without waiting for a server-push integration.
 */
const status = asyncHandler(async (req, res) => {
  const user = await findUserWithToken(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  const changed = await reconcileSubscription(user);
  if (changed) await user.save();
  return res.json({ user: user.toPublicJSON() });
});

module.exports = { verify, status };
