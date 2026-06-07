const Location = require('../models/Location');
const asyncHandler = require('../utils/asyncHandler');

const listLocations = asyncHandler(async (req, res) => {
  const locations = await Location.find({ userId: req.user.userId }).sort({ name: 1 });
  res.json({ locations });
});

const createLocation = asyncHandler(async (req, res) => {
  const { name, lat, lng, type } = req.body;
  if (!name || lat == null || lng == null) {
    return res.status(400).json({ error: 'name, lat and lng are required' });
  }
  const location = await Location.create({ userId: req.user.userId, name, lat, lng, type });
  res.status(201).json({ location });
});

const updateLocation = asyncHandler(async (req, res) => {
  const location = await Location.findOne({ _id: req.params.id, userId: req.user.userId });
  if (!location) return res.status(404).json({ error: 'Location not found' });
  for (const field of ['name', 'lat', 'lng', 'type']) {
    if (req.body[field] !== undefined) location[field] = req.body[field];
  }
  await location.save();
  res.json({ location });
});

const deleteLocation = asyncHandler(async (req, res) => {
  const result = await Location.deleteOne({ _id: req.params.id, userId: req.user.userId });
  if (result.deletedCount === 0) return res.status(404).json({ error: 'Location not found' });
  res.status(204).end();
});

module.exports = { listLocations, createLocation, updateLocation, deleteLocation };
