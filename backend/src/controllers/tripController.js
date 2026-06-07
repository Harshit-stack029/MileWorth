const mongoose = require('mongoose');
const Trip = require('../models/Trip');
const User = require('../models/User');
const asyncHandler = require('../utils/asyncHandler');
const { computeDeduction } = require('../utils/deduction');
const { autoClassify } = require('../utils/autoClassify');

// List the authenticated user's trips, newest first. Optional ?category= filter.
const listTrips = asyncHandler(async (req, res) => {
  const filter = { userId: req.user.userId };
  if (req.query.category) filter.category = req.query.category;
  const trips = await Trip.find(filter).sort({ startTime: -1 }).limit(500);
  res.json({ trips });
});

const getTrip = asyncHandler(async (req, res) => {
  const trip = await Trip.findOne({ _id: req.params.id, userId: req.user.userId });
  if (!trip) return res.status(404).json({ error: 'Trip not found' });
  res.json({ trip });
});

const createTrip = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const {
    startTime, endTime, distance, category: requested = 'uncategorized',
    startLat, startLng, endLat, endLng, routePolyline,
    startLocationId, endLocationId,
  } = req.body;

  if (startTime == null || endTime == null || distance == null) {
    return res.status(400).json({ error: 'startTime, endTime and distance are required' });
  }

  // Apply auto-classification rules to anything left uncategorized (FR-14).
  const category = autoClassify({
    category: requested,
    startTime,
    settings: { classifyWeekendsAsPersonal: user.classifyWeekendsAsPersonal },
  });

  const deductionValue = computeDeduction({ distance, category, mileageRate: user.mileageRate });

  const trip = await Trip.create({
    userId: user._id,
    startTime, endTime, distance, category,
    startLat, startLng, endLat, endLng, routePolyline,
    startLocationId, endLocationId, deductionValue,
  });
  res.status(201).json({ trip });
});

// Edit / reclassify. Recomputes deduction if distance or category changes.
const updateTrip = asyncHandler(async (req, res) => {
  const trip = await Trip.findOne({ _id: req.params.id, userId: req.user.userId });
  if (!trip) return res.status(404).json({ error: 'Trip not found' });

  const editable = [
    'startTime', 'endTime', 'distance', 'category', 'startLat', 'startLng',
    'endLat', 'endLng', 'routePolyline', 'startLocationId', 'endLocationId',
  ];
  for (const field of editable) {
    if (req.body[field] !== undefined) trip[field] = req.body[field];
  }

  const user = await User.findById(req.user.userId);
  trip.deductionValue = computeDeduction({
    distance: trip.distance,
    category: trip.category,
    mileageRate: user.mileageRate,
  });

  await trip.save();
  res.json({ trip });
});

const deleteTrip = asyncHandler(async (req, res) => {
  const result = await Trip.deleteOne({ _id: req.params.id, userId: req.user.userId });
  if (result.deletedCount === 0) return res.status(404).json({ error: 'Trip not found' });
  res.status(204).end();
});

// Dashboard totals: miles tracked, work-drive count, total deductions.
const getSummary = asyncHandler(async (req, res) => {
  const userId = req.user.userId;
  const [agg] = await Trip.aggregate([
    { $match: { userId: new mongoose.Types.ObjectId(String(userId)) } },
    {
      $group: {
        _id: null,
        totalMiles: { $sum: '$distance' },
        totalTrips: { $sum: 1 },
        businessTrips: {
          $sum: { $cond: [{ $eq: ['$category', 'business'] }, 1, 0] },
        },
        uncategorizedTrips: {
          $sum: { $cond: [{ $eq: ['$category', 'uncategorized'] }, 1, 0] },
        },
        totalDeductions: { $sum: '$deductionValue' },
      },
    },
  ]);

  res.json({
    summary: {
      totalMiles: agg?.totalMiles || 0,
      totalTrips: agg?.totalTrips || 0,
      businessTrips: agg?.businessTrips || 0,
      uncategorizedTrips: agg?.uncategorizedTrips || 0,
      totalDeductions: Math.round((agg?.totalDeductions || 0) * 100) / 100,
    },
  });
});

// Insights (FR-11): category breakdown for the pie chart + top locations.
const getInsights = asyncHandler(async (req, res) => {
  const oid = new mongoose.Types.ObjectId(String(req.user.userId));

  const byCategory = await Trip.aggregate([
    { $match: { userId: oid } },
    {
      $group: {
        _id: '$category',
        count: { $sum: 1 },
        miles: { $sum: '$distance' },
        value: { $sum: '$deductionValue' },
      },
    },
    { $sort: { count: -1 } },
  ]);

  // Top end-locations by trip count (only trips that have a named location).
  const topLocations = await Trip.aggregate([
    { $match: { userId: oid, endLocationId: { $ne: null } } },
    {
      $group: {
        _id: '$endLocationId',
        count: { $sum: 1 },
        value: { $sum: '$deductionValue' },
      },
    },
    { $sort: { count: -1 } },
    { $limit: 10 },
    {
      $lookup: {
        from: 'locations',
        localField: '_id',
        foreignField: '_id',
        as: 'location',
      },
    },
    { $unwind: '$location' },
    {
      $project: {
        _id: 0,
        name: '$location.name',
        count: 1,
        value: { $round: ['$value', 2] },
      },
    },
  ]);

  res.json({
    insights: {
      byCategory: byCategory.map((c) => ({
        category: c._id,
        count: c.count,
        miles: Math.round(c.miles * 100) / 100,
        value: Math.round(c.value * 100) / 100,
      })),
      topLocations,
    },
  });
});

module.exports = {
  listTrips, getTrip, createTrip, updateTrip, deleteTrip, getSummary, getInsights,
};
