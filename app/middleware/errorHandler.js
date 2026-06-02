/**
 * middleware/errorHandler.js — Global Error Handler
 *
 * Express error-handling middleware must have exactly 4 parameters:
 * (err, req, res, next). Express will route any error passed to next(err)
 * here automatically.
 *
 * Why centralise error handling?
 *  - Consistent JSON error shape for API consumers
 *  - Never leak stack traces to clients in production
 *  - Single place to add alerting/reporting (e.g. Sentry)
 */

'use strict';

const logger = require('../utils/logger');

/**
 * Normalises an error into a structured JSON response.
 * Stack traces are included ONLY in development.
 */
const errorHandler = (err, req, res, next) => { // eslint-disable-line no-unused-vars
  // Default to 500 if no status was set on the error
  const statusCode = err.statusCode || err.status || 500;

  // Log the full error internally
  logger.error({
    message: err.message,
    statusCode,
    path: req.path,
    method: req.method,
    stack: err.stack,
  });

  // Build response payload
  const response = {
    status: 'error',
    statusCode,
    message: statusCode < 500 ? err.message : 'Internal Server Error',
  };

  // Expose stack trace only in development
  if (process.env.NODE_ENV === 'development') {
    response.stack = err.stack;
  }

  res.status(statusCode).json(response);
};

/**
 * Helper to create an operational error with a custom HTTP status code.
 * Usage: throw createError(404, 'Resource not found')
 */
const createError = (statusCode, message) => {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
};

module.exports = { errorHandler, createError };
