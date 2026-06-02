/**
 * tests/app.test.js — Unit & Integration Tests
 *
 * We use supertest to make HTTP requests directly against the Express app
 * without binding to a real port. This makes tests fast, isolated, and
 * repeatable in CI — no "Address already in use" errors.
 *
 * Coverage is enforced via Jest's coverageThreshold in package.json.
 * The pipeline will fail if coverage drops below 70%.
 */

'use strict';

const request = require('supertest');
const app     = require('../app');

// ─── Root Endpoint ───────────────────────────────────────────────────────────
describe('GET /', () => {
  it('should return 200 with status ok', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.message).toMatch(/running/i);
    expect(res.body.timestamp).toBeDefined();
  });
});

// ─── Health Endpoint ─────────────────────────────────────────────────────────
describe('GET /health', () => {
  it('should return 200 with healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
  });

  it('should include uptime, memory, and system info', async () => {
    const res = await request(app).get('/health');
    expect(res.body.uptime).toBeDefined();
    expect(res.body.memory).toBeDefined();
    expect(res.body.memory.heapUsed).toBeDefined();
    expect(res.body.system).toBeDefined();
    expect(res.body.system.nodeVersion).toBeDefined();
  });

  it('should include environment field', async () => {
    const res = await request(app).get('/health');
    expect(res.body.environment).toBeDefined();
  });
});

// ─── API Status Endpoint ──────────────────────────────────────────────────────
describe('GET /api/status', () => {
  it('should return 200 with operational status', async () => {
    const res = await request(app).get('/api/status');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('operational');
  });

  it('should include services object', async () => {
    const res = await request(app).get('/api/status');
    expect(res.body.services).toBeDefined();
    expect(res.body.services.api).toBe('up');
  });

  it('should include metadata object', async () => {
    const res = await request(app).get('/api/status');
    expect(res.body.metadata).toBeDefined();
    expect(res.body.metadata.region).toBeDefined();
  });

  it('should include a requestId', async () => {
    const res = await request(app).get('/api/status');
    expect(res.body.requestId).toBeDefined();
  });
});

// ─── Version Endpoint ─────────────────────────────────────────────────────────
describe('GET /version', () => {
  it('should return 200 with version info', async () => {
    const res = await request(app).get('/version');
    expect(res.statusCode).toBe(200);
    expect(res.body.version).toBeDefined();
    expect(res.body.nodeVersion).toBeDefined();
  });

  it('should include buildNumber and gitCommit', async () => {
    const res = await request(app).get('/version');
    expect(res.body.buildNumber).toBeDefined();
    expect(res.body.gitCommit).toBeDefined();
  });
});

// ─── 404 Handler ──────────────────────────────────────────────────────────────
describe('Unknown routes', () => {
  it('should return 404 for unknown GET routes', async () => {
    const res = await request(app).get('/this-route-does-not-exist');
    expect(res.statusCode).toBe(404);
    expect(res.body.status).toBe('error');
  });

  it('should return 404 for unknown POST routes', async () => {
    const res = await request(app).post('/unknown');
    expect(res.statusCode).toBe(404);
  });
});

// ─── Security Headers ─────────────────────────────────────────────────────────
describe('Security headers (helmet)', () => {
  it('should set X-Content-Type-Options header', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('should set X-Frame-Options header', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-frame-options']).toBeDefined();
  });
});
