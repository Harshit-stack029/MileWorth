const Expense = require('../models/Expense');
const asyncHandler = require('../utils/asyncHandler');

// Cap receipt data URLs so a base64 image can't blow past Mongo's 16MB doc
// limit. Production should move receipts to object storage (S3/GridFS) and store
// only a URL here. Kept below the 3mb express.json body limit in app.js.
const MAX_RECEIPT_CHARS = 2_000_000; // ~1.5MB image
// Accept only image data URLs (jpeg/png/webp/gif/heic) or http(s) URLs.
const DATA_URL_RE = /^data:image\/(jpeg|jpg|png|webp|gif|heic|heif);base64,/i;
const HTTP_URL_RE = /^https?:\/\//i;

// Returns an error string if the receipt value is unacceptable, else null.
function validateReceipt(receiptImageUrl) {
  if (receiptImageUrl == null) return null;
  if (typeof receiptImageUrl !== 'string') return 'receiptImageUrl must be a string';
  if (receiptImageUrl.length > MAX_RECEIPT_CHARS) return 'Receipt image is too large';
  if (!DATA_URL_RE.test(receiptImageUrl) && !HTTP_URL_RE.test(receiptImageUrl)) {
    return 'receiptImageUrl must be an image data URL or http(s) link';
  }
  return null;
}

// Keep in sync with the enum in models/Expense.js.
const PAYMENT_METHODS = ['cash', 'card', 'other'];

// Returns an error string if paymentMethod is provided but invalid, else null.
function validatePaymentMethod(paymentMethod) {
  if (paymentMethod == null) return null;
  if (!PAYMENT_METHODS.includes(paymentMethod)) {
    return `paymentMethod must be one of: ${PAYMENT_METHODS.join(', ')}`;
  }
  return null;
}

// Fields the schema gives a default. Persisting an explicit null would defeat
// that default rather than fall back to it — paymentMethod would fail the enum
// validator, and an `isDeductible: null` would quietly drop the expense out of
// every deduction total. Treat it as a client error instead.
const DEFAULTED_FIELDS = ['currency', 'paymentMethod', 'isDeductible'];

// Returns an error string if a defaulted field was explicitly set to null.
function validateDefaultedFields(body) {
  for (const field of DEFAULTED_FIELDS) {
    if (body[field] === null) {
      return `${field} may not be null — omit it to use the default`;
    }
  }
  return null;
}

const listExpenses = asyncHandler(async (req, res) => {
  const expenses = await Expense.find({ userId: req.user.userId }).sort({ date: -1 });
  res.json({ expenses });
});

const createExpense = asyncHandler(async (req, res) => {
  const {
    date, vendor, category, amount, receiptImageUrl,
    currency, paymentMethod, notes, isDeductible,
  } = req.body;
  if (date == null || amount == null) {
    return res.status(400).json({ error: 'date and amount are required' });
  }
  if (!(Number(amount) > 0)) {
    return res.status(400).json({ error: 'amount must be a positive number' });
  }
  const receiptError = validateReceipt(receiptImageUrl);
  if (receiptError) {
    const status = receiptError.includes('too large') ? 413 : 400;
    return res.status(status).json({ error: receiptError });
  }
  const nullError = validateDefaultedFields(req.body);
  if (nullError) return res.status(400).json({ error: nullError });
  const paymentError = validatePaymentMethod(paymentMethod);
  if (paymentError) return res.status(400).json({ error: paymentError });
  const expense = await Expense.create({
    userId: req.user.userId,
    date, vendor, category, amount, receiptImageUrl,
    currency, paymentMethod, notes, isDeductible,
  });
  res.status(201).json({ expense });
});

const updateExpense = asyncHandler(async (req, res) => {
  const expense = await Expense.findOne({ _id: req.params.id, userId: req.user.userId });
  if (!expense) return res.status(404).json({ error: 'Expense not found' });
  if (req.body.amount !== undefined && !(Number(req.body.amount) > 0)) {
    return res.status(400).json({ error: 'amount must be a positive number' });
  }
  if (req.body.receiptImageUrl !== undefined) {
    const receiptError = validateReceipt(req.body.receiptImageUrl);
    if (receiptError) {
      const status = receiptError.includes('too large') ? 413 : 400;
      return res.status(status).json({ error: receiptError });
    }
  }
  const nullError = validateDefaultedFields(req.body);
  if (nullError) return res.status(400).json({ error: nullError });
  if (req.body.paymentMethod !== undefined) {
    const paymentError = validatePaymentMethod(req.body.paymentMethod);
    if (paymentError) return res.status(400).json({ error: paymentError });
  }
  for (const field of [
    'date', 'vendor', 'category', 'amount', 'receiptImageUrl',
    'currency', 'paymentMethod', 'notes', 'isDeductible',
  ]) {
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

module.exports = {
  listExpenses, createExpense, updateExpense, deleteExpense,
  validateReceipt, MAX_RECEIPT_CHARS,
  validatePaymentMethod, validateDefaultedFields, PAYMENT_METHODS,
};
