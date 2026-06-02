/**
 * server.js — Application Entry Point
 *
 * This file bootstraps the Express app, wires middleware,
 * mounts routes, and starts the HTTP server.
 * It is intentionally thin: business logic lives in routes/controllers.
 */

'use strict';

require('dotenv').config();              // Load .env into process.env FIRST
const app    = require('./app');         // Configured Express instance
const logger = require('./utils/logger');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0'; // Bind to all interfaces inside Docker

// Start HTTP server
const server = app.listen(PORT, HOST, () => {
  logger.info(`Server running on http://${HOST}:${PORT}`);
  logger.info(`Environment : ${process.env.NODE_ENV || 'development'}`);
  logger.info(`App version : ${process.env.npm_package_version || '1.0.0'}`);
});

// ─── Graceful Shutdown ──────────────────────────────────────────────────────
// When Kubernetes/Docker sends SIGTERM (container stop), finish in-flight
// requests before exiting rather than abruptly killing connections.

const shutdown = (signal) => {
  logger.info(`Received ${signal}. Shutting down gracefully...`);
  server.close(() => {
    logger.info('HTTP server closed. Exiting process.');
    process.exit(0);
  });

  // Force-kill after 10 s if requests are still hanging
  setTimeout(() => {
    logger.error('Could not close connections in time, forcefully shutting down');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));

// Unhandled promise rejections — log and exit so the process restarts cleanly
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

module.exports = server; // Exported for integration tests
