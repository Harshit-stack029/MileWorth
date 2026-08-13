const mongoose = require('mongoose');

// Phase 2 feature, but the model is defined now so the schema is stable.
const expenseSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    date: { type: Date, required: true },
    vendor: { type: String, trim: true },
    category: { type: String, trim: true },
    amount: { type: Number, required: true, min: 0 },
    currency: { type: String, trim: true, uppercase: true, default: 'USD' },
    paymentMethod: {
      type: String,
      enum: ['cash', 'card', 'other'],
      default: 'other',
    },
    notes: { type: String, trim: true },
    isDeductible: { type: Boolean, default: true },
    receiptImageUrl: String,
  },
  { timestamps: true }
);

module.exports = mongoose.model('Expense', expenseSchema);
