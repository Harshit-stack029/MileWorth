// Central error handler. Maps common Mongoose/validation errors to clean responses.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err.name === 'ValidationError') {
    return res.status(400).json({ error: err.message });
  }
  if (err.code === 11000) {
    return res.status(409).json({ error: 'Resource already exists' });
  }
  if (err.name === 'CastError') {
    return res.status(400).json({ error: `Invalid ${err.path}` });
  }
  // eslint-disable-next-line no-console
  console.error('[error]', err);
  return res.status(500).json({ error: 'Internal server error' });
}

function notFound(req, res) {
  res.status(404).json({ error: 'Not found' });
}

module.exports = { errorHandler, notFound };
