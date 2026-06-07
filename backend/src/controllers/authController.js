const jwt = require('jsonwebtoken');
const User = require('../models/User');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');

function signToken(user) {
  return jwt.sign({}, env.jwtSecret, {
    subject: user._id.toString(),
    expiresIn: env.jwtExpiresIn,
  });
}

const register = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: 'password must be at least 8 characters' });
  }
  const existing = await User.findOne({ email: email.toLowerCase() });
  if (existing) {
    return res.status(409).json({ error: 'An account with that email already exists' });
  }
  const user = new User({ email });
  await user.setPassword(password);
  await user.save();
  return res.status(201).json({ token: signToken(user), user: user.toPublicJSON() });
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }
  const user = await User.findOne({ email: email.toLowerCase() });
  if (!user || !(await user.verifyPassword(password))) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }
  return res.json({ token: signToken(user), user: user.toPublicJSON() });
});

const me = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  return res.json({ user: user.toPublicJSON() });
});

const updateSettings = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  const { mileageRate, currency, classifyWeekendsAsPersonal } = req.body;
  if (mileageRate != null) {
    const rate = Number(mileageRate);
    if (!Number.isFinite(rate) || rate <= 0) {
      return res.status(400).json({ error: 'mileageRate must be a positive number' });
    }
    user.mileageRate = rate;
  }
  if (currency != null) user.currency = currency;
  if (classifyWeekendsAsPersonal != null) {
    user.classifyWeekendsAsPersonal = classifyWeekendsAsPersonal;
  }
  await user.save();
  return res.json({ user: user.toPublicJSON() });
});

module.exports = { register, login, me, updateSettings };
