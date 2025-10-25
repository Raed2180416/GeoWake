/// Centralized configuration for alarm, routing, deviation and ETA related thresholds.
/// All numeric constants are aggregated here so they can be tuned, A/B tested,
/// or overridden in tests without hunting through service code.
///
/// **Purpose**: Single source of truth for all timing, distance, and speed thresholds
/// used throughout the tracking and alarm system. This prevents magic numbers from
/// being scattered across the codebase and enables easy tuning.
///
/// **Usage**: Access via `ThresholdsProvider.current` which can be replaced in tests
/// or at runtime to experiment with different threshold values.
class AlarmAndRoutingThresholds {
  // Movement classification thresholds (m/s)
  /// Upper bound for walking speed in meters per second
  /// Above this speed, user is likely not walking (might be jogging or in vehicle)
  final double walkSpeedUpperMps;        // Above this is no longer definitely walking
  
  /// Lower bound for driving speed in meters per second
  /// At or above this speed, user is likely in a vehicle
  final double driveSpeedLowerMps;       // At / above this likely driving
  
  /// GPS noise floor - speeds below this are treated as stationary/noise
  /// Helps filter out GPS jitter when user is not actually moving
  final double gpsNoiseFloorMps;         // Speeds below treated as noise / stationary

  // Fallback representative speeds (m/s) used if we have insufficient recent samples
  /// Typical adult walking speed (~5 km/h) used when no recent samples available
  final double fallbackWalkMps;          // Typical adult walking speed ~1.4 m/s
  
  /// Conservative city driving speed (~30 km/h) used as fallback
  final double fallbackDriveMps;         // Conservative city driving speed ~8.3 m/s (30 km/h)

  // Deviation (off-route) dynamic threshold components
  /// Base lateral deviation before considering user off-route
  /// Minimum allowable offset from route polyline
  final double baseDeviationMeters;      // Minimum allowable lateral offset before flag
  
  /// Fraction of current segment length used to scale deviation threshold
  /// Longer segments allow more lateral flexibility
  final double deviationFractionSegment; // Fraction of current segment length used to scale threshold
  
  /// Maximum deviation threshold cap (prevents runaway on very long segments)
  final double deviationMaxMeters;       // Cap to avoid runaway for very long segments

  // Destination pre‑fire distance (meters)
  /// Distance from destination at which we consider user "approaching"
  /// Used for preliminary checks before firing destination alarm
  final double preDestinationMeters;     // Distance at which we consider user "approaching" destination

  // Time alarm gating - prevents false positives when tracking just started
  /// Minimum time elapsed since tracking started before time-based alarms are eligible
  final Duration minSinceStart;          // Minimum elapsed time since tracking start
  
  /// Minimum distance traveled before time-based alarms are eligible
  /// Ensures user has actually started moving, not just sitting at start point
  final double minDistanceSinceStartMeters; // Minimum traveled distance for time alarm eligibility
  
  /// Minimum number of ETA samples needed before time alarm is eligible
  /// Ensures ETA has stabilized before triggering
  final int minEtaSamples;               // Minimum ETA samples before eligibility

  // Debounce / blackout windows - prevent alarm spam
  /// Time route must continuously appear better before switching to it
  /// Prevents rapid oscillation between routes
  final Duration routeSwitchSustain;     // Required continuous confirmation before switching
  
  /// Blackout period after route switch during which further switches are ignored
  final Duration postSwitchBlackout;     // Ignore further switches immediately after one
  
  /// Time user must continuously deviate before firing deviation alarm
  /// Prevents false alarms from temporary GPS drift
  final Duration deviationSustain;       // Required continuous deviation before firing deviation alarm

  // Alarm restore / duplicate grace
  /// Grace period during which duplicate alarms are suppressed after process restart
  /// Prevents re-firing alarm that was already shown before app was killed
  final Duration alarmRestoreGrace;      // Prevent duplicate alarm after process restart

  // Reroute / GPS buffers
  /// Minimum time between route recalculation attempts
  /// Prevents excessive API calls and battery drain
  final Duration rerouteCooldown;        // Min interval between recalculation attempts
  
  /// Time to wait after GPS dropout before enabling sensor fusion fallback
  /// Allows GPS to recover naturally before using IMU/sensor data
  final Duration gpsDropoutBuffer;       // Time before enabling sensor fusion fallback

  // UI / progress
  /// Throttle interval for updating progress notification
  /// Prevents excessive UI updates and improves performance
  final Duration progressUiInterval;     // Throttle for progress notification updates

  /// Constructor with sensible defaults tuned through testing
  const AlarmAndRoutingThresholds({
    this.walkSpeedUpperMps = 2.6,        // ~9.4 km/h: brisk walk / jog boundary
    this.driveSpeedLowerMps = 4.5,       // ~16.2 km/h: well above cycling casual, below car typical
    this.gpsNoiseFloorMps = 0.3,         // Sub‑0.3 often jitter
    this.fallbackWalkMps = 1.4,
    this.fallbackDriveMps = 8.3,         // 30 km/h
    this.baseDeviationMeters = 40.0,
    this.deviationFractionSegment = 0.15,
    this.deviationMaxMeters = 200.0,
    this.preDestinationMeters = 500.0,
    this.minSinceStart = const Duration(seconds: 30),
    this.minDistanceSinceStartMeters = 100.0,
    this.minEtaSamples = 3,
    this.routeSwitchSustain = const Duration(seconds: 6),
    this.postSwitchBlackout = const Duration(seconds: 5),
    this.deviationSustain = const Duration(seconds: 5),
    this.alarmRestoreGrace = const Duration(minutes: 2),
    this.rerouteCooldown = const Duration(seconds: 30),
    this.gpsDropoutBuffer = const Duration(seconds: 30),
    this.progressUiInterval = const Duration(milliseconds: 300),
  });
}

/// Global mutable holder (can be replaced in tests). In production prefer DI.
/// 
/// **Usage**: 
/// - Production: Use default values via `ThresholdsProvider.current`
/// - Tests: Replace with custom thresholds via `ThresholdsProvider.current = ...`
class ThresholdsProvider {
  /// Current active threshold configuration
  /// Can be mutated for testing or runtime A/B experiments
  static AlarmAndRoutingThresholds current = const AlarmAndRoutingThresholds();
}
