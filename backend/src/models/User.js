const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const env = require('../config/env');

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: { type: String, required: true },
    // Standard mileage rate (currency per mile/km). Configurable — never hardcoded
    // because it changes yearly and by country.
    mileageRate: { type: Number, default: env.defaultMileageRate },
    currency: { type: String, default: env.defaultCurrency },
    subscriptionStatus: {
      type: String,
      enum: ['free', 'active', 'cancelled'],
      default: 'free',
    },
    // Latest Google Play purchase token for the subscription. Kept server-side
    // so we can re-verify entitlement with Google after the current period ends
    // (renewal pushes expiry forward; a lapse/cancel revokes Pro). Never sent to
    // the client. The token is stable across auto-renewals in subscriptionsv2.
    purchaseToken: { type: String, select: false },
    subscriptionProductId: { type: String },
    // When the current paid period ends. While this is in the future we trust
    // the cached `active` status without calling Google; once it passes we
    // re-verify (or, for mock billing, lapse the account).
    subscriptionExpiry: { type: Date },
    // Auto-classification rule (FR-14): weekend drives default to personal.
    classifyWeekendsAsPersonal: { type: Boolean, default: false },
    // Email verification state (set true after the user confirms via the
    // emailed link). New accounts start unverified.
    emailVerified: { type: Boolean, default: false },
  },
  { timestamps: true }
);

userSchema.methods.setPassword = async function setPassword(plain) {
  this.passwordHash = await bcrypt.hash(plain, 10);
};

userSchema.methods.verifyPassword = function verifyPassword(plain) {
  return bcrypt.compare(plain, this.passwordHash);
};

// True while the cached subscription is still within its paid period. Used to
// skip a Google round-trip on every request — we only re-verify once expiry
// passes. A missing expiry is treated as "needs verification".
userSchema.methods.subscriptionUnexpired = function subscriptionUnexpired(now = new Date()) {
  return Boolean(this.subscriptionExpiry && this.subscriptionExpiry.getTime() > now.getTime());
};

// Persist the outcome of a (re-)verification. `entitled` decides the Pro flag;
// `expiry` (ms epoch or null) and token/productId are cached for next time.
userSchema.methods.recordSubscription = function recordSubscription({
  entitled, expiryMs, purchaseToken, productId,
}) {
  this.subscriptionStatus = entitled ? 'active' : 'cancelled';
  this.subscriptionExpiry = expiryMs ? new Date(expiryMs) : undefined;
  if (purchaseToken !== undefined) this.purchaseToken = purchaseToken;
  if (productId !== undefined) this.subscriptionProductId = productId;
};

// Strip sensitive fields from JSON responses.
userSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id,
    email: this.email,
    mileageRate: this.mileageRate,
    currency: this.currency,
    subscriptionStatus: this.subscriptionStatus,
    subscriptionExpiry: this.subscriptionExpiry || null,
    classifyWeekendsAsPersonal: this.classifyWeekendsAsPersonal,
    emailVerified: this.emailVerified,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);
