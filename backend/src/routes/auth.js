const express = require('express');
const auth = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimit');
const ctrl = require('../controllers/authController');

const router = express.Router();

router.post('/register', authLimiter, ctrl.register);
router.post('/login', authLimiter, ctrl.login);
router.post('/forgot-password', authLimiter, ctrl.requestPasswordReset);
router.post('/reset-password', authLimiter, ctrl.resetPassword);
router.post('/verify-email', authLimiter, ctrl.verifyEmail);
router.get('/verify-email', ctrl.verifyEmail); // emailed link lands here
router.get('/me', auth, ctrl.me);
router.patch('/me/settings', auth, ctrl.updateSettings);
router.post('/me/resend-verification', auth, ctrl.resendVerification);
router.delete('/me', auth, ctrl.deleteAccount);

module.exports = router;
