/**
 * middleware/requestLogger.js — Per-Request Structured Logging
 *
 * Attaches a unique request ID to every incoming request and logs
 * the result once the response is finished. This is essential for:
 *   - Correlating log lines to a single request in distributed systems
 *   - Performance monitoring (response time)
 *   - Audit trails
 */

'use strict';

const logger = require('../utils/logger');  

const requestLogger = (req, res, next) => {
  // Attach a simple request ID (timestamp + random hex)
  req.requestId = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const startTime = Date.now();

  // Log when the response finishes (not on request — we want status + duration)
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    logger.info({
      requestId : req.requestId,
      method    : req.method,
      path      : req.path,
      status    : res.statusCode,
      duration  : `${duration}ms`,
      ip        : req.ip || req.connection.remoteAddress,
      userAgent : req.get('User-Agent'),
    });
  });

  next();
};

module.exports = { requestLogger };
