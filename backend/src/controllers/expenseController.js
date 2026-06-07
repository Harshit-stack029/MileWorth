const Expense = require('../models/Expense');
const asyncHandler = require('../utils/asyncHandler');

// Cap receipt data URLs so a base64 image can't blow past Mongo's 16MB doc
// limit. Production should move receipts to object storage (S3/GridFS) and store
// only a URL here.
const MAX_RECEIPT_CHARS = 2_000_000; // ~1.5MB image

const listExpenses = asyncHandler(async (req, res) => {
  const expenses = await Expense.find({ userId: req.user.userId }).sort({ date: -1 });
  res.json({ expenses });
});

const createExpense = asyncHandler(async (req, res) => {
  const { date, vendor, category, amount, receiptImageUrl } = req.body;
  if (date == null || amount == null) {
    return res.status(400).json({ error: 'date and amount are required' });
  }
  if (receiptImageUrl && receiptImageUrl.length > MAX_RECEIPT_CHARS) {
    return res.status(413).json({ error: 'Receipt image is too large' });
  }
  const expense = await Expense.create({
    userId: req.user.userId,
    date, vendor, category, amount, receiptImageUrl,
  });
  res.status(201).json({ expense });
});

const updateExpense = asyncHandler(async (req, res) => {
  const expense = await Expense.findOne({ _id: req.params.id, userId: req.user.userId });
  if (!expense) return res.status(404).json({ error: 'Expense not found' });
  for (const field of ['date', 'vendor', 'category', 'amount', 'receiptImageUrl']) {
    if (req.body[field] !== undefined) expense[field] = req.body[field];
  }
  await expense.save();
  res.json({ expense });
});

const deleteExpense = asyncHandler(async (req, res) => {
  const result = await Expense.deleteOne({ _id: req.params.id, userId: req.user.userId });
  if (result.deletedCount === 0) return res.status(404).json({ error: 'Expense not found' });
  res.status(204).end();
});

module.exports = { listExpenses, createExpense, updateExpense, deleteExpense };
