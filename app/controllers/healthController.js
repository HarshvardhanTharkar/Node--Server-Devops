/**
 * controllers/healthController.js — Health Check Logic
 *
 * Controllers contain the business logic for a route.
 * Separating them from routes enables unit testing without HTTP overhead.
 *
 * The health check follows the standard pattern used by AWS ALB target groups:
 *   - Return HTTP 200 if healthy
 *   - Return HTTP 503 if any critical dependency is unavailable
 *
 * For this demo the only dependency is the process itself,
 * but you would add database connectivity checks here in production.
 */

'use strict';

const os = require('os');

/**
 * GET /
 * Minimal root response — confirms the service is reachable.
 */
const root = (req, res) => {
  res.status(200).json({
    status  : 'ok',
    message : 'Node.js CI/CD Demo App is running',
    timestamp: new Date().toISOString(),
  });
};

/**
 * GET /health
 * Detailed health payload consumed by load balancers and monitoring tools.
 *
 * uptime        — how long the Node process has been running (seconds)
 * memoryUsage   — RSS + heap stats, useful for detecting memory leaks
 * cpuLoad       — 1/5/15 minute load averages
 * environment   — which NODE_ENV the process is running under
 */
const health = (req, res) => {
  const { rss, heapUsed, heapTotal } = process.memoryUsage();

  const healthData = {
    status     : 'healthy',
    timestamp  : new Date().toISOString(),
    uptime     : `${Math.floor(process.uptime())}s`,
    environment: process.env.NODE_ENV || 'development',
    version    : process.env.npm_package_version || '1.0.0',
    system: {
      platform : process.platform,
      nodeVersion: process.version,
      hostname : os.hostname(),
      cpuLoad  : os.loadavg(),
    },
    memory: {
      rss      : `${Math.round(rss      / 1024 / 1024)} MB`,
      heapUsed : `${Math.round(heapUsed / 1024 / 1024)} MB`,
      heapTotal: `${Math.round(heapTotal/ 1024 / 1024)} MB`,
    },
  };

  res.status(200).json(healthData);
};

module.exports = { root, health };
