/// Centralized configuration for alarm, routing, deviation and ETA related thresholds.
/// All numeric constants are aggregated here so they can be tuned, A/B tested,
/// or overridden in tests without hunting through service code.
class AlarmAndRoutingThresholds {
  // Movement classification thresholds (m/s)
  final double walkSpeedUpperMps;        // Above this is no longer definitely walking
  final double driveSpeedLowerMps;       // At / above this likely driving
  final double gpsNoiseFloorMps;         // Speeds below treated as noise / stationary

  // Fallback representative speeds (m/s) used if we have insufficient recent samples
  final double fallbackWalkMps;          // Typical adult walking speed ~1.4 m/s
  final double fallbackDriveMps;         // Conservative city driving speed ~8.3 m/s (30 km/h)

  // Deviation (off-route) dynamic threshold components
  final double baseDeviationMeters;      // Minimum allowable lateral offset before flag
  final double deviationFractionSegment; // Fraction of current segment length used to scale threshold
  final double deviationMaxMeters;       // Cap to avoid runaway for very long segments

  // Destination pre‑fire distance (meters)
  final double preDestinationMeters;     // Distance at which we consider user "approaching" destination

  // Time alarm gating
  final Duration minSinceStart;          // Minimum elapsed time since tracking start
  final double minDistanceSinceStartMeters; // Minimum traveled distance for time alarm eligibility
  final int minEtaSamples;               // Minimum ETA samples before eligibility

  // Debounce / blackout windows
  final Duration routeSwitchSustain;     // Required continuous confirmation before switching
  final Duration postSwitchBlackout;     // Ignore further switches immediately after one
  final Duration deviationSustain;       // Required continuous deviation before firing deviation alarm

  // Alarm restore / duplicate grace
  final Duration alarmRestoreGrace;      // Prevent duplicate alarm after process restart

  // Reroute / GPS buffers
  final Duration rerouteCooldown;        // Min interval between recalculation attempts
  final Duration gpsDropoutBuffer;       // Time before enabling sensor fusion fallback

  // UI / progress
  final Duration progressUiInterval;     // Throttle for progress notification updates

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
class ThresholdsProvider {
  static AlarmAndRoutingThresholds current = const AlarmAndRoutingThresholds();
}
