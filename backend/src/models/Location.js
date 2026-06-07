const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: { type: String, required: true, trim: true },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    type: {
      type: String,
      enum: ['home', 'work', 'supplier', 'custom'],
      default: 'custom',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Location', locationSchema);
