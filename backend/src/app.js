const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const env = require('./config/env');
const { errorHandler, notFound } = require('./middleware/error');

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));
if (env.nodeEnv !== 'test') app.use(morgan('dev'));

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'mileworth-api' }));

app.use('/auth', require('./routes/auth'));
app.use('/trips', require('./routes/trips'));
app.use('/locations', require('./routes/locations'));
app.use('/expenses', require('./routes/expenses'));
app.use('/reports', require('./routes/reports'));
app.use('/billing', require('./routes/billing'));

app.use(notFound);
app.use(errorHandler);

module.exports = app;
