const express = require('express');
const auth = require('../middleware/auth');
const ctrl = require('../controllers/locationController');

const router = express.Router();

router.use(auth);

router.get('/', ctrl.listLocations);
router.post('/', ctrl.createLocation);
router.patch('/:id', ctrl.updateLocation);
router.delete('/:id', ctrl.deleteLocation);

module.exports = router;
