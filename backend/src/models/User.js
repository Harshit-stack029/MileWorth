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

// Strip sensitive fields from JSON responses.
userSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id,
    email: this.email,
    mileageRate: this.mileageRate,
    currency: this.currency,
    subscriptionStatus: this.subscriptionStatus,
    classifyWeekendsAsPersonal: this.classifyWeekendsAsPersonal,
    emailVerified: this.emailVerified,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('User', userSchema);
