const express = require('express');
const auth = require('../middleware/auth');
const ctrl = require('../controllers/tripController');

const router = express.Router();

// All trip routes require authentication.
router.use(auth);

router.get('/summary', ctrl.getSummary);
router.get('/insights', ctrl.getInsights);
router.get('/', ctrl.listTrips);
router.post('/', ctrl.createTrip);
router.get('/:id', ctrl.getTrip);
router.patch('/:id', ctrl.updateTrip);
router.delete('/:id', ctrl.deleteTrip);

module.exports = router;
