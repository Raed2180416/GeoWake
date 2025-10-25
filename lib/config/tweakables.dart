/// Centralized configuration for all tweakable values throughout the app.
/// This file consolidates magic numbers and constants that were previously
/// hardcoded across different files. All values are documented with their
/// purpose and original location.
///
/// IMPORTANT: When changing values here, ensure they don't break functionality.
/// Test thoroughly after any modifications.

class GeoWakeTweakables {
  // ============================================================================
  // ROUTE CACHE CONFIGURATION
  // ============================================================================
  
  /// Time-to-live for cached route data.
  /// Routes older than this are considered stale and will be refetched.
  /// Original location: lib/services/route_cache.dart
  static const Duration routeCacheTtl = Duration(minutes: 5);
  
  /// Maximum distance (in meters) that the user's current location can deviate
  /// from the cached route's origin point before the cache is considered invalid.
  /// This prevents using a cached route when the user has moved significantly.
  /// Original location: lib/services/route_cache.dart
  static const double routeCacheOriginDeviationMeters = 300.0;
  
  /// Maximum number of route entries to keep in cache.
  /// Older entries are evicted when this limit is reached.
  /// Original location: lib/services/route_cache.dart
  static const int routeCacheMaxEntries = 30;
  
  // ============================================================================
  // TRANSIT & STOPS CONFIGURATION
  // ============================================================================
  
  /// Heuristic value for meters per transit stop.
  /// Used to estimate distance when alarm is set by number of stops.
  /// Based on typical urban transit stop spacing.
  /// Original location: lib/services/trackingservice.dart
  static const double stopsHeuristicMetersPerStop = 550.0;
  
  /// Minimum distance for pre-boarding alarm window (in meters).
  /// This is the closest distance at which pre-boarding alarm can fire.
  /// Original location: lib/services/trackingservice/alarm.dart (inferred from code)
  static const double preBoardingMinDistanceMeters = 400.0;
  
  /// Maximum distance for pre-boarding alarm window (in meters).
  /// This is the furthest distance at which pre-boarding alarm can fire.
  /// Original location: lib/services/trackingservice/alarm.dart (inferred from code)
  static const double preBoardingMaxDistanceMeters = 1500.0;
  
  // ============================================================================
  // UI ANIMATION CONFIGURATION
  // ============================================================================
  
  /// Pulse animation multiplier for active dot in pulsing dots widget.
  /// The active dot scales to this multiplier of the base size.
  /// Original location: lib/widgets/pulsing_dots.dart
  static const double pulsingDotsActiveMultiplier = 1.8;
  
  /// Animation duration for pulsing dots (in milliseconds).
  /// Controls how fast the dots pulse.
  /// Original location: lib/widgets/pulsing_dots.dart (default behavior)
  static const int pulsingDotsAnimationDurationMs = 500;
  
  // ============================================================================
  // ALARM CONFIGURATION
  // ============================================================================
  
  /// Default alarm distance threshold for demo/testing (in meters).
  /// Used when no specific distance is provided.
  /// Original location: Various demo/test files
  static const double defaultAlarmDistanceMeters = 200.0;
  
  /// Minimum number of consecutive position updates required before
  /// an alarm condition is considered stable and fires.
  /// Prevents false positives from GPS jitter.
  /// Original location: lib/services/trackingservice/alarm.dart (inferred)
  static const int alarmProximityPassesRequired = 3;
  
  /// Duration to dwell near target location before alarm fires (in seconds).
  /// Helps prevent false alarms from brief GPS fluctuations.
  /// Original location: lib/services/trackingservice/alarm.dart (inferred)
  static const int alarmProximityDwellSeconds = 4;
  
  // ============================================================================
  // NETWORK & API CONFIGURATION
  // ============================================================================
  
  /// Maximum number of retry attempts for failed network requests.
  /// Applies to API calls that fail due to network issues.
  /// To be used in: lib/services/api_client.dart
  static const int networkMaxRetries = 3;
  
  /// Initial delay between retry attempts (in seconds).
  /// Delay doubles on each retry (exponential backoff).
  /// To be used in: lib/services/api_client.dart
  static const int networkRetryInitialDelaySeconds = 1;
  
  /// Maximum retry delay (in seconds) to cap exponential backoff.
  /// Prevents extremely long wait times.
  /// To be used in: lib/services/api_client.dart
  static const int networkRetryMaxDelaySeconds = 30;
  
  // ============================================================================
  // LOCATION & GPS CONFIGURATION
  // ============================================================================
  
  /// Minimum distance moved (in meters) before position update is considered significant.
  /// Helps filter out GPS noise when stationary.
  /// Original location: Various tracking service files
  static const double gpsMinimumMovementMeters = 5.0;
  
  /// Maximum age of GPS location before it's considered stale (in seconds).
  /// Stale locations are not used for navigation decisions.
  /// Original location: Various tracking service files
  static const int gpsMaxLocationAgeSeconds = 30;
  
  // ============================================================================
  // BATTERY & POWER OPTIMIZATION
  // ============================================================================
  
  /// Minimum battery level (percentage) at which to request battery optimization
  /// exemption from the user. Below this level, accurate tracking is critical.
  /// To be used in: Battery optimization guidance
  static const int batteryOptimizationThresholdPercent = 20;
  
  // ============================================================================
  // PERMISSION MONITORING
  // ============================================================================
  
  /// Interval (in seconds) between runtime permission checks.
  /// Monitors for permission revocation during active tracking.
  /// To be used in: Permission monitoring service
  static const int permissionCheckIntervalSeconds = 30;
  
  // ============================================================================
  // ROUTE SWITCHING & DEVIATION
  // ============================================================================
  
  /// Minimum distance from destination (in meters) before route switching is disabled.
  /// Prevents switching to alternative routes when already near destination.
  /// Original location: lib/services/active_route_manager.dart (inferred)
  static const double routeSwitchDisableNearDestinationMeters = 200.0;
  
  /// Margin distance (in meters) that a new route must be better by before
  /// switching from current route. Prevents unnecessary route flapping.
  /// Original location: lib/services/active_route_manager.dart
  static const double routeSwitchMarginMeters = 50.0;
  
  // ============================================================================
  // DATA MIGRATION & CLEANUP
  // ============================================================================
  
  /// Maximum number of recent location entries to keep in history.
  /// Older entries are pruned to prevent unbounded growth.
  /// Original location: lib/screens/otherimpservices/recent_locations_service.dart
  static const int recentLocationsMaxEntries = 100;
  
  /// Age (in days) after which old location history is automatically deleted.
  /// Helps maintain privacy and reduce storage usage.
  /// To be used in: Location history cleanup
  static const int recentLocationsMaxAgeDays = 30;
  
  // ============================================================================
  // ACCESSIBILITY
  // ============================================================================
  
  /// Minimum speed (in m/s) for time-based alarm eligibility.
  /// Lowered from 0.5 to 0.3 to support slower-walking users.
  /// Original location: lib/config/alarm_thresholds.dart
  /// Recommendation from audit: Lower to 0.3 for accessibility
  static const double timeAlarmMinimumSpeedMps = 0.3;
  
  // ============================================================================
  // SPLASH SCREEN & INITIALIZATION
  // ============================================================================
  
  /// Duration (in seconds) before splash screen fallback navigation triggers.
  /// If bootstrap doesn't complete in time, this ensures app doesn't hang.
  /// Original location: lib/screens/splash_screen.dart
  static const int splashScreenFallbackTimeoutSeconds = 7;
  
  /// Duration (in milliseconds) before splash screen text animation starts.
  /// Original location: lib/screens/splash_screen.dart
  static const int splashScreenTextDelayMs = 800;
  
  /// Duration (in seconds) for splash screen animation.
  /// Original location: lib/screens/splash_screen.dart
  static const int splashScreenAnimationDurationSeconds = 2;
  
  // ============================================================================
  // ROUTE SWITCHING & DEVIATION DETECTION
  // ============================================================================
  
  /// Base deviation threshold (in meters) when online.
  /// Used to determine if user has deviated from the route.
  /// Original location: lib/services/deviation_detection.dart
  static const double deviationThresholdOnlineMeters = 600.0;
  
  /// Base deviation threshold (in meters) when offline.
  /// Higher threshold to account for reduced GPS accuracy.
  /// Original location: lib/services/deviation_detection.dart
  static const double deviationThresholdOfflineMeters = 1500.0;
  
  /// Base speed threshold (in m/s) for deviation hysteresis.
  /// Original location: lib/services/deviation_monitor.dart
  static const double deviationSpeedThresholdBase = 15.0;
  
  /// Speed threshold coefficient for deviation detection.
  /// Multiplied by current speed to get adaptive threshold.
  /// Original location: lib/services/deviation_monitor.dart
  static const double deviationSpeedThresholdK = 1.5;
  
  /// Hysteresis ratio for deviation threshold.
  /// Lower threshold uses this ratio of the upper threshold.
  /// Original location: lib/services/deviation_monitor.dart
  static const double deviationHysteresisRatio = 0.7;
  
  /// Duration to sustain deviation before considering it persistent.
  /// Original location: lib/services/deviation_monitor.dart
  static const Duration deviationSustainDuration = Duration(seconds: 5);
  
  /// Radius (in meters) for route candidate search.
  /// Original location: lib/services/active_route_manager.dart
  static const double routeCandidateSearchRadiusMeters = 1200.0;
  
  /// Maximum number of route candidates to consider.
  /// Original location: lib/services/active_route_manager.dart
  static const int routeCandidateMaxCount = 3;
  
  /// Duration candidate route must be better before switching.
  /// Original location: lib/services/active_route_manager.dart
  static const Duration routeSwitchSustainDuration = Duration(seconds: 6);
  
  /// Blackout period after route switch before allowing another switch.
  /// Original location: lib/services/active_route_manager.dart
  static const Duration routeSwitchBlackoutDuration = Duration(seconds: 5);
  
  /// Size of bearing sample window for route validation.
  /// Original location: lib/services/active_route_manager.dart
  static const int routeBearingWindowSize = 5;
  
  /// Minimum bearing samples required for validation.
  /// Original location: lib/services/active_route_manager.dart
  static const int routeBearingMinSamples = 3;
  
  /// Search window size for route snap operations.
  /// Original location: lib/services/active_route_manager.dart
  static const int routeSnapSearchWindow = 30;
  
  // ============================================================================
  // ALARM DEDUPLICATION
  // ============================================================================
  
  /// Cleanup interval for alarm deduplicator (in minutes).
  /// Expired entries are cleaned up at this interval.
  /// Original location: lib/services/alarm_deduplicator.dart
  static const int alarmDeduplicatorCleanupIntervalMinutes = 10;
  
  // ============================================================================
  // API CLIENT CONFIGURATION
  // ============================================================================
  
  /// Timeout for API authentication requests (in seconds).
  /// Original location: lib/services/api_client.dart
  static const int apiAuthTimeoutSeconds = 10;
  
  /// Timeout for general API requests (in seconds).
  /// Original location: lib/services/api_client.dart
  static const int apiRequestTimeoutSeconds = 15;
  
  /// Default token expiration fallback (in hours).
  /// Used if server doesn't provide expiration time.
  /// Original location: lib/services/api_client.dart
  static const int apiTokenDefaultExpirationHours = 24;
  
  /// Default place search radius (in meters).
  /// Original location: lib/services/api_client.dart
  static const int apiPlaceSearchRadiusMeters = 500;
  
  /// Response body preview length for logging.
  /// Original location: lib/services/api_client.dart
  static const int apiResponsePreviewLength = 200;
  
  // ============================================================================
  // BACKGROUND SERVICE
  // ============================================================================
  
  /// Recovery attempt interval (in seconds).
  /// Original location: lib/services/background_service_recovery.dart
  static const int backgroundServiceRecoveryIntervalSeconds = 30;
  
  /// Bootstrap session load timeout (in milliseconds).
  /// Original location: lib/services/bootstrap_service.dart
  static const int bootstrapSessionLoadTimeoutMs = 600;
  
  /// Bootstrap late recovery timeout (in milliseconds).
  /// Original location: lib/services/bootstrap_service.dart
  static const int bootstrapLateRecoveryTimeoutMs = 1500;
}
