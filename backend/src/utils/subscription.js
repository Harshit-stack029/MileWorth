const User = require('../models/User');
const googlePlay = require('./googlePlay');

// Load a user WITH the (normally hidden) purchase token, needed for re-verifying.
function findUserWithToken(userId) {
  return User.findById(userId).select('+purchaseToken');
}

/**
 * Bring a user's cached subscription state in line with Google.
 *
 * This is what closes the "status never flips back from active" gap: a
 * subscription that lapses, is put on hold, or whose cancellation finally
 * expires gets downgraded; a renewal pushes the expiry forward and keeps Pro.
 *
 * To avoid a Google round-trip on every request we trust the cached `active`
 * status while `subscriptionExpiry` is still in the future, and only re-verify
 * once it has passed. Returns true if anything changed (so the caller saves).
 */
async function reconcileSubscription(user) {
  if (user.subscriptionStatus !== 'active') return false;
  if (user.subscriptionUnexpired()) return false; // still inside the paid period

  // Period has ended (or we never recorded an expiry). Decide if it renewed.
  if (user.purchaseToken && googlePlay.isConfigured()) {
    let result;
    try {
      result = await googlePlay.verifySubscription({ purchaseToken: user.purchaseToken });
    } catch (err) {
      // Transient Google/network error: don't punish the user on a blip — leave
      // the (now-stale) active flag for the next attempt rather than guessing.
      // eslint-disable-next-line no-console
      console.error('[billing] re-verification failed, leaving status unchanged:', err.message);
      return false;
    }
    user.recordSubscription({
      entitled: result.entitled,
      expiryMs: result.expiryMs,
      productId: user.subscriptionProductId,
    });
    return true;
  }

  // No token to check (mock-billing path) and the period has elapsed: lapse it.
  user.recordSubscription({ entitled: false, expiryMs: null });
  return true;
}

module.exports = { findUserWithToken, reconcileSubscription };
