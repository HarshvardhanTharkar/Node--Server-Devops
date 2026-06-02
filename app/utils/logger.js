/**
 * utils/logger.js — Centralized Winston Logger
 *
 * All application logging goes through this module so we have:
 *   - Structured JSON logs in production (easy to ingest into CloudWatch/ELK)
 *   - Colorized human-readable logs in development
 *   - Consistent log levels across the codebase
 */

'use strict';

const { createLogger, format, transports } = require('winston');

const { combine, timestamp, printf, colorize, errors } = format;

// Custom log format for development (colorized, readable)
const devFormat = combine(
  colorize({ all: true }),
  timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp, stack }) => {
    return stack
      ? `${timestamp} [${level}]: ${message}\n${stack}`
      : `${timestamp} [${level}]: ${message}`;
  })
);

// Structured JSON format for production (CloudWatch / ELK / Splunk friendly)
const prodFormat = combine(
  timestamp(),
  errors({ stack: true }),
  format.json()
);

const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: process.env.NODE_ENV === 'production' ? prodFormat : devFormat,
  defaultMeta: {
    service: 'nodejs-cicd-app',
    version: process.env.npm_package_version || '1.0.0',
  },
  transports: [
    new transports.Console(),
  ],
  // Do not exit on handled exceptions
  exitOnError: false,
});

// Add custom 'http' level used by morgan
logger.http = (message) => logger.log('http', message);

module.exports = logger;
