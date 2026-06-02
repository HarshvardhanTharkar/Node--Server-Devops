/**
 * app.js — Express Application Configuration
 *
 * Separating the app setup from server.js lets us import the
 * configured app in tests without actually binding to a port.
 */

'use strict';

const express      = require('express');
const helmet       = require('helmet');
const cors         = require('cors');
const morgan       = require('morgan');
const rateLimit    = require('express-rate-limit');

const logger            = require('./utils/logger');
const { errorHandler }  = require('./middleware/errorHandler');
const { requestLogger } = require('./middleware/requestLogger');

// Route modules
const healthRoutes  = require('./routes/health');
const apiRoutes     = require('./routes/api');
const versionRoutes = require('./routes/version');

const app = express();

// ─── Security Middleware ────────────────────────────────────────────────────
// helmet sets ~14 HTTP headers (X-Content-Type-Options, Strict-Transport-Security, etc.)
app.use(helmet());

// CORS — restrict to your front-end origin in production via ALLOWED_ORIGINS env var
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '*').split(',');
app.use(cors({
  origin: allowedOrigins,
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ─── Rate Limiting ──────────────────────────────────────────────────────────
// Prevents brute-force/DoS. 100 req/15 min per IP.
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
});
app.use(limiter);

// ─── Body Parsing ───────────────────────────────────────────────────────────
app.use(express.json({ limit: '10kb' })); // Prevent large-payload attacks
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// ─── HTTP Request Logging ───────────────────────────────────────────────────
// morgan → winston integration so all log output goes through one transport
app.use(morgan('combined', {
  stream: { write: (msg) => logger.http(msg.trim()) }
}));
app.use(requestLogger);

// ─── Routes ─────────────────────────────────────────────────────────────────
app.use('/',        healthRoutes);   // GET /  and GET /health
app.use('/api',     apiRoutes);      // GET /api/status
app.use('/version', versionRoutes);  // GET /version

// ─── 404 Handler ────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: `Route ${req.method} ${req.path} not found`,
  });
});

// ─── Global Error Handler ────────────────────────────────────────────────────
// Must have 4 parameters — Express detects this as an error-handling middleware
app.use(errorHandler);

module.exports = app;
