/// interfaces.dart: Source file from lib/lib/services/refactor/interfaces.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'location_types.dart';

/// LocationPipeline: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class LocationPipeline {
  Stream<LocationSample> get samples$;
  /// start: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> start(LocationPipelineConfig config);
  /// stop: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> stop();
  /// applyCadence: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> applyCadence(LocationCadence cadence); // may internally resubscribe
}

/// LocationPipelineConfig: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class LocationPipelineConfig {
  /// [Brief description of this field]
  final bool enableSensorFusionFallback;
  /// [Brief description of this field]
  final Duration gpsDropoutThreshold;
  const LocationPipelineConfig({
    this.enableSensorFusionFallback = true,
    this.gpsDropoutThreshold = const Duration(seconds: 8),
  });
}

/// LocationCadence: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class LocationCadence {
  /// [Brief description of this field]
  final int distanceFilterMeters;
  /// [Brief description of this field]
  final String accuracyProfile; // e.g., high|balanced|low
  const LocationCadence({required this.distanceFilterMeters, required this.accuracyProfile});
}

/// PowerModeController: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class PowerModeController {
  Stream<PowerMode> get mode$;
  /// ingest: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void ingest(LocationSample sample);
  PowerMode get currentMode;
}

/// DeviationEngine: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class DeviationEngine {
  /// Returns snapped position (may just echo raw with placeholder initially)
  SnappedPosition snap(LocationSample sample);
  /// Evaluates deviation classification.
  DeviationResult classify(LocationSample sample, SnappedPosition snapped);
  /// Optional suggested route switch routeId (null if none)
  String? evaluateRouteSwitch(SnappedPosition snapped);
  /// resetOnRouteChange: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void resetOnRouteChange();
}

/// AlarmOrchestrator: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class AlarmOrchestrator {
  Stream<AlarmEvent> get events$;
  /// update: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void update({required LocationSample sample, required SnappedPosition? snapped});
  /// configure: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void configure(AlarmConfig config);
  /// registerDestination: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void registerDestination(DestinationSpec spec);
  /// reset: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void reset();
}

/// AlarmConfig: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class AlarmConfig {
  /// [Brief description of this field]
  final double distanceThresholdMeters; // distance alarm radius
  /// [Brief description of this field]
  final double timeETALimitSeconds; // time-based alarm threshold
  /// [Brief description of this field]
  final int minEtaSamples;
  /// [Brief description of this field]
  final double stopsThreshold; // for stops-based mode
  // Time eligibility gating overrides (to mirror legacy heuristics while allowing tests to relax them)
  /// [Brief description of this field]
  final double minTimeEligibilityDistanceMeters; // movement required before ETA alarms considered
  /// [Brief description of this field]
  final Duration minTimeEligibilitySinceStart; // minimum session age before considering ETA alarm
  const AlarmConfig({
    required this.distanceThresholdMeters,
    required this.timeETALimitSeconds,
    required this.minEtaSamples,
    required this.stopsThreshold,
    this.minTimeEligibilityDistanceMeters = 100.0,
    this.minTimeEligibilitySinceStart = const Duration(seconds: 30),
  });
}

/// DestinationSpec: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class DestinationSpec {
  /// [Brief description of this field]
  final double lat;
  /// [Brief description of this field]
  final double lng;
  /// [Brief description of this field]
  final String name;
  const DestinationSpec({required this.lat, required this.lng, required this.name});
}

/// SessionStateStore: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class SessionStateStore {
  /// save: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> save(SessionSnapshot snapshot);
  /// load: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<SessionSnapshot?> load();
  /// clear: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> clear();
}

/// SessionSnapshot: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class SessionSnapshot {
  /// [Brief description of this field]
  final String? activeRouteId;
  /// [Brief description of this field]
  final double? progressMeters;
  /// [Brief description of this field]
  final bool alarmEligible;
  /// [Brief description of this field]
  final DateTime savedAt;
  const SessionSnapshot({
    required this.activeRouteId,
    required this.progressMeters,
    required this.alarmEligible,
    required this.savedAt,
  });
}

/// NotificationGateway: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class NotificationGateway {
  /// showProgress: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> showProgress({required double percent, required String title, String? subtitle});
  /// showAlarm: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> showAlarm({required String title, required String body});
  /// stopAlarm: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> stopAlarm();
  /// updatePowerMode: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> updatePowerMode(PowerMode mode);
}

/// TrackingSessionFacade: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class TrackingSessionFacade {
  /// start: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> start({required DestinationSpec destination, required AlarmConfig alarmConfig});
  /// stop: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> stop();
  Stream<AlarmEvent> get alarmEvents$;
  Stream<PowerMode> get powerMode$;
}
