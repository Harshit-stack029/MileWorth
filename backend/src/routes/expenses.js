const express = require('express');
const auth = require('../middleware/auth');
const ctrl = require('../controllers/expenseController');

const router = express.Router();

router.use(auth);

router.get('/', ctrl.listExpenses);
router.post('/', ctrl.createExpense);
router.patch('/:id', ctrl.updateExpense);
router.delete('/:id', ctrl.deleteExpense);

module.exports = router;
