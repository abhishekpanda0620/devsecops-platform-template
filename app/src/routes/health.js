/**
 * Health Check Routes
 * Kubernetes-compatible health endpoints
 */

const express = require('express');
const router = express.Router();

// Track service start time
const startTime = Date.now();

/**
 * GET /health
 * Basic health check
 */
router.get('/', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: Math.floor((Date.now() - startTime) / 1000)
    });
});

/**
 * GET /health/live
 * Kubernetes liveness probe
 * Returns 200 if the service is alive
 */
router.get('/live', (req, res) => {
    res.json({ status: 'alive' });
});

/**
 * GET /health/ready
 * Kubernetes readiness probe
 * Returns 200 if the service is ready to accept traffic
 */
router.get('/ready', (req, res) => {
    // Add checks for dependencies (database, cache, etc.)
    const checks = {
        memory: process.memoryUsage().heapUsed < 500 * 1024 * 1024, // Less than 500MB
        uptime: process.uptime() > 0
    };

    const isReady = Object.values(checks).every(check => check === true);

    if (isReady) {
        res.json({
            status: 'ready',
            checks
        });
    } else {
        res.status(503).json({
            status: 'not ready',
            checks
        });
    }
});

/**
 * GET /health/metrics
 * Basic metrics endpoint
 */
router.get('/metrics', (req, res) => {
    const memUsage = process.memoryUsage();

    res.json({
        uptime: process.uptime(),
        memory: {
            heapTotal: memUsage.heapTotal,
            heapUsed: memUsage.heapUsed,
            external: memUsage.external,
            rss: memUsage.rss
        },
        cpu: process.cpuUsage(),
        version: process.version,
        platform: process.platform,
        arch: process.arch
    });
});

module.exports = router;
