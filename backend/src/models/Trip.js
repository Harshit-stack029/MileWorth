const mongoose = require('mongoose');

const CATEGORIES = ['business', 'personal', 'uncategorized'];

const tripSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    startTime: { type: Date, required: true },
    endTime: { type: Date, required: true },
    // Distance in miles (or km — interpreted per the user's mileageRate unit).
    distance: { type: Number, required: true, min: 0 },
    startLat: Number,
    startLng: Number,
    endLat: Number,
    endLng: Number,
    // Encoded polyline of the recorded route.
    routePolyline: String,
    category: {
      type: String,
      enum: CATEGORIES,
      default: 'uncategorized',
      index: true,
    },
    startLocationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Location' },
    endLocationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Location' },
    // Cached deduction value at the rate in effect when computed.
    deductionValue: { type: Number, default: 0 },
  },
  { timestamps: true }
);

tripSchema.index({ userId: 1, startTime: -1 });

module.exports = mongoose.model('Trip', tripSchema);
module.exports.CATEGORIES = CATEGORIES;
