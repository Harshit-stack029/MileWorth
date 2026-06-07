// Wraps an async route handler so thrown/rejected errors hit the error middleware.
module.exports = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
