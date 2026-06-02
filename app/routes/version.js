/**
 * routes/version.js — Version Route
 *
 * Exposes build/version metadata. Useful for:
 *   - Confirming the correct image was deployed
 *   - Debugging version mismatches in multi-region deployments
 *   - Automated post-deployment verification scripts
 *
 * GET /version → returns app version + build info
 */

'use strict';

const express = require('express');
const router  = express.Router();

const versionController = require('../controllers/versionController');

router.get('/', versionController.version);

module.exports = router;
