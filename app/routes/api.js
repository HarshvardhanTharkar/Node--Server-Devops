/**
 * routes/api.js — API Routes
 *
 * All application API endpoints are mounted under /api.
 * This namespace separation makes it easy to:
 *   - Version the API later (/api/v2/...)
 *   - Apply API-specific middleware (auth, throttling)
 *   - Distinguish API traffic from static/health traffic in logs
 *
 * GET /api/status  → current application status
 */

'use strict';

const express = require('express');
const router  = express.Router();

const apiController = require('../controllers/apiController');

router.get('/status', apiController.status);

module.exports = router;
