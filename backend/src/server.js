const app = require('./app');
const env = require('./config/env');
const { connectDB } = require('./config/db');

async function start() {
  try {
    await connectDB();
    app.listen(env.port, () => {
      // eslint-disable-next-line no-console
      console.log(`[server] MileWorth API listening on http://localhost:${env.port}`);
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[server] Failed to start:', err.message);
    process.exit(1);
  }
}

start();
