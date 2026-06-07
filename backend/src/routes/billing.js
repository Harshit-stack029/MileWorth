const express = require('express');
const auth = require('../middleware/auth');
const ctrl = require('../controllers/billingController');

const router = express.Router();

router.use(auth);

router.post('/verify', ctrl.verify);

module.exports = router;
