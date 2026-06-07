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
    receiptImageUrl: String,
  },
  { timestamps: true }
);

module.exports = mongoose.model('Expense', expenseSchema);
