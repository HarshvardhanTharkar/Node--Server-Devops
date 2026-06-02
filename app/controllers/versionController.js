/**
 * controllers/versionController.js — Build / Version Metadata
 *
 * At build time the CI pipeline injects environment variables:
 *   APP_VERSION  — semver from package.json
 *   GIT_COMMIT   — short commit SHA (git rev-parse --short HEAD)
 *   BUILD_NUMBER — Jenkins build number
 *   BUILD_DATE   — ISO timestamp of the build
 *
 * This endpoint is called by the post-deployment health check in Jenkinsfile
 * to confirm that the freshly deployed image matches the expected build.
 */

'use strict';

const version = (req, res) => {
  res.status(200).json({
    name        : process.env.npm_package_name    || 'nodejs-cicd-app',
    version     : process.env.APP_VERSION         || process.env.npm_package_version || '1.0.0',
    gitCommit   : process.env.GIT_COMMIT          || 'unknown',
    buildNumber : process.env.BUILD_NUMBER        || 'local',
    buildDate   : process.env.BUILD_DATE          || 'unknown',
    nodeVersion : process.version,
    environment : process.env.NODE_ENV            || 'development',
    timestamp   : new Date().toISOString(),
  });
};

module.exports = { version };
