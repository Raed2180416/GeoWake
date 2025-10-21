// src/routes/health.js
const express = require('express');
const axios = require('axios');
const config = require('../config/config');

const router = express.Router();

// Cache for API key validation result
let apiKeyValidationCache = {
  isValid: null,
  lastChecked: null,
  error: null
};

// Cache duration: 5 minutes
const CACHE_DURATION_MS = 5 * 60 * 1000;

/**
 * Validate Google Maps API Key by making a simple geocoding request
 * This is cached to avoid hitting API limits
 */
async function validateGoogleMapsApiKey() {
  const now = Date.now();
  
  // Return cached result if still valid
  if (apiKeyValidationCache.lastChecked && 
      (now - apiKeyValidationCache.lastChecked) < CACHE_DURATION_MS) {
    return {
      isValid: apiKeyValidationCache.isValid,
      cached: true,
      lastChecked: new Date(apiKeyValidationCache.lastChecked).toISOString(),
      error: apiKeyValidationCache.error
    };
  }
  
  try {
    // Make a minimal geocoding request to validate the API key
    // Using a well-known location to minimize data transfer
    const response = await axios.get(config.googleMapsUrls.geocoding, {
      params: {
        address: '1600 Amphitheatre Parkway, Mountain View, CA',
        key: config.googleMapsApiKey
      },
      timeout: 5000
    });
    
    // Check if the request was successful
    const isValid = response.data.status === 'OK' || response.data.status === 'ZERO_RESULTS';
    
    // Update cache
    apiKeyValidationCache = {
      isValid,
      lastChecked: now,
      error: isValid ? null : response.data.error_message || response.data.status
    };
    
    return {
      isValid,
      cached: false,
      lastChecked: new Date(now).toISOString(),
      error: apiKeyValidationCache.error
    };
  } catch (error) {
    // Cache the error result
    apiKeyValidationCache = {
      isValid: false,
      lastChecked: now,
      error: error.message
    };
    
    return {
      isValid: false,
      cached: false,
      lastChecked: new Date(now).toISOString(),
      error: error.message
    };
  }
}

/**
 * GET /api/health
 * Enhanced health check endpoint with API key validation
 */
router.get('/', async (req, res) => {
  const includeApiCheck = req.query.full === 'true';
  
  const healthStatus = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    environment: config.nodeEnv,
    services: {
      server: 'ok'
    }
  };
  
  // If full health check requested, validate API key
  if (includeApiCheck) {
    const apiKeyStatus = await validateGoogleMapsApiKey();
    healthStatus.services.googleMapsApi = apiKeyStatus.isValid ? 'ok' : 'degraded';
    healthStatus.apiKeyValidation = apiKeyStatus;
    
    // If API key is invalid, set overall status to degraded
    if (!apiKeyStatus.isValid) {
      healthStatus.status = 'degraded';
    }
  }
  
  // Return appropriate HTTP status code
  const httpStatus = healthStatus.status === 'ok' ? 200 : 503;
  res.status(httpStatus).json(healthStatus);
});

/**
 * GET /api/health/ready
 * Kubernetes-style readiness probe
 */
router.get('/ready', async (req, res) => {
  try {
    // Check if API key is configured
    if (!config.googleMapsApiKey) {
      return res.status(503).json({
        ready: false,
        reason: 'Google Maps API key not configured'
      });
    }
    
    // Perform API key validation
    const apiKeyStatus = await validateGoogleMapsApiKey();
    
    if (!apiKeyStatus.isValid) {
      return res.status(503).json({
        ready: false,
        reason: 'Google Maps API key validation failed',
        error: apiKeyStatus.error
      });
    }
    
    res.json({
      ready: true,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      ready: false,
      reason: error.message
    });
  }
});

/**
 * GET /api/health/live
 * Kubernetes-style liveness probe (basic check)
 */
router.get('/live', (req, res) => {
  res.json({
    alive: true,
    timestamp: new Date().toISOString()
  });
});

module.exports = router;
