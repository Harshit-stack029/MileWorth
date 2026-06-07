const mongoose = require('mongoose');
const env = require('./env');

async function connectDB() {
  if (!env.mongoUri) {
    throw new Error('MONGODB_URI is not set — cannot connect to MongoDB');
  }
  mongoose.set('strictQuery', true);
  await mongoose.connect(env.mongoUri);
  // eslint-disable-next-line no-console
  console.log('[db] Connected to MongoDB');
}

module.exports = { connectDB };
