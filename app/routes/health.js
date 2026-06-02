/**
 * routes/health.js — Health & Root Routes
 *
 * Health check endpoints are critical in containerised environments:
 *   - Docker uses HEALTHCHECK to decide if the container is healthy
 *   - Kubernetes readiness/liveness probes hit these endpoints
 *   - Load balancers (ALB) use them to decide whether to send traffic
 *
 * GET /        → root, quick sanity check
 * GET /health  → detailed health status
 */

'use strict';

const express = require('express');
const router  = express.Router();

const healthController = require('../controllers/healthController');

// Root endpoint — used by a quick "is it up?" check
router.get('/', healthController.root);

// Detailed health endpoint — used by load-balancer health checks
router.get('/health', healthController.health);

module.exports = router;
