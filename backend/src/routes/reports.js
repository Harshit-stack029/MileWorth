const express = require('express');
const auth = require('../middleware/auth');
const ctrl = require('../controllers/reportController');

const router = express.Router();

router.use(auth);

router.get('/summary', ctrl.getReportSummary);
router.get('/', ctrl.getReport); // ?format=pdf|csv&from=&to=

module.exports = router;
