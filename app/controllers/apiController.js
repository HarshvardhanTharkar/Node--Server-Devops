/**
 * controllers/apiController.js — API Business Logic
 *
 * In a real application this controller would interact with a database,
 * call external services, and apply business rules.
 * For this demo it returns application status metadata.
 */

'use strict';

/**
 * GET /api/status
 * Returns the current operational status of the application.
 *
 * In production you would:
 *   1. Ping the database and set status to 'degraded' on failure
 *   2. Check downstream service health
 *   3. Return appropriate HTTP status codes (200/503) so load balancers
 *      can take unhealthy instances out of rotation automatically
 */
const status = (req, res) => {
  const appStatus = {
    status     : 'operational',
    timestamp  : new Date().toISOString(),
    requestId  : req.requestId,           // Injected by requestLogger middleware
    environment: process.env.NODE_ENV || 'development',
    services: {
      api      : 'up',
      database : 'N/A (demo)',            // Replace with real DB ping
      cache    : 'N/A (demo)',            // Replace with Redis ping
    },
    metadata: {
      region   : process.env.AWS_REGION   || 'us-east-1',
      instance : process.env.INSTANCE_ID  || 'local',
      commit   : process.env.GIT_COMMIT   || 'unknown',
    },
  };

  res.status(200).json(appStatus);
};

module.exports = { status };
