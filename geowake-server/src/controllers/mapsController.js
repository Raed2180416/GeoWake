// src/controllers/mapsController.js
const axios = require('axios');
const config = require('../config/config');
const cache = require('../utils/cache');

/**
 * A generic function to proxy requests to the Google Maps API.
 * It handles caching and adds the API key securely on the server-side.
 */
const googleApiProxy = async (req, res, { url, params, cacheType, cacheParams }) => {
  // Check cache first
  const cachedData = cache.get(cacheType, cacheParams);
  if (cachedData) {
    return res.json(cachedData);
  }

  try {
    const response = await axios.get(url, {
      params: {
        ...params,
        key: config.googleMapsApiKey
      }
    });

    // Cache the successful response
    cache.set(cacheType, cacheParams, response.data);

    res.json(response.data);
  } catch (error) {
    console.error(`❌ Google Maps API Error at ${url}:`, error.response ? error.response.data : error.message);
    res.status(error.response?.status || 500).json({
      success: false,
      error: 'An error occurred while fetching data from Google Maps API.',
      details: error.response?.data?.error_message || 'Internal server error.'
    });
  }
};

// Handler for Directions API
const getDirections = (req, res) => {
  const { origin, destination, mode } = req.body;
  googleApiProxy(req, res, {
    url: config.googleMapsUrls.directions,
    params: { origin, destination, mode },
    cacheType: 'directions',
    cacheParams: { origin, destination, mode }
  });
};

// Handler for Autocomplete API
const getAutocomplete = (req, res) => {
  const { input, sessiontoken } = req.body;
  googleApiProxy(req, res, {
    url: config.googleMapsUrls.places,
    params: { input, sessiontoken },
    cacheType: 'places',
    cacheParams: { input }
  });
};

// Handler for Place Details API
const getPlaceDetails = (req, res) => {
  const { place_id, sessiontoken } = req.body;
  googleApiProxy(req, res, {
    url: config.googleMapsUrls.placeDetails,
    params: { place_id, sessiontoken, fields: 'name,geometry,formatted_address' },
    cacheType: 'place-details',
    cacheParams: { place_id }
  });
};

// Handler for Geocoding API
const getGeocoding = (req, res) => {
  const { address } = req.body;
  googleApiProxy(req, res, {
    url: config.googleMapsUrls.geocoding,
    params: { address },
    cacheType: 'geocoding',
    cacheParams: { address }
  });
};

// Handler for Nearby Search API
const getNearbySearch = (req, res) => {
  const { location, radius, type } = req.body; // location should be "lat,lng"
  googleApiProxy(req, res, {
    url: config.googleMapsUrls.nearbySearch,
    params: { location, radius, type },
    cacheType: 'nearby-search',
    cacheParams: { location, radius, type }
  });
};

module.exports = {
  getDirections,
  getAutocomplete,
  getPlaceDetails,
  getGeocoding,
  getNearbySearch
};