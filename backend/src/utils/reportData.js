const mongoose = require('mongoose');
const Trip = require('../models/Trip');
const Expense = require('../models/Expense');

/// Gather everything a report needs for a [from, to] date window.
async function gatherReportData(userId, from, to) {
  const oid = new mongoose.Types.ObjectId(String(userId));
  const range = {};
  if (from) range.$gte = new Date(from);
  if (to) range.$lte = new Date(to);
  const hasRange = Object.keys(range).length > 0;

  const trips = await Trip.find({
    userId: oid,
    ...(hasRange ? { startTime: range } : {}),
  }).sort({ startTime: 1 });

  const expenses = await Expense.find({
    userId: oid,
    ...(hasRange ? { date: range } : {}),
  }).sort({ date: 1 });

  const businessTrips = trips.filter((t) => t.category === 'business');
  const totals = {
    totalTrips: trips.length,
    businessTrips: businessTrips.length,
    businessMiles: round(businessTrips.reduce((s, t) => s + t.distance, 0)),
    totalMiles: round(trips.reduce((s, t) => s + t.distance, 0)),
    totalDeductions: round(trips.reduce((s, t) => s + (t.deductionValue || 0), 0)),
    totalExpenses: round(expenses.reduce((s, e) => s + e.amount, 0)),
  };

  return { trips, expenses, totals, from, to };
}

function round(n) {
  return Math.round(n * 100) / 100;
}

module.exports = { gatherReportData };
