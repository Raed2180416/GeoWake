import 'location_types.dart';

abstract class LocationPipeline {
  Stream<LocationSample> get samples$;
  Future<void> start(LocationPipelineConfig config);
  Future<void> stop();
  Future<void> applyCadence(LocationCadence cadence); // may internally resubscribe
}

class LocationPipelineConfig {
  final bool enableSensorFusionFallback;
  final Duration gpsDropoutThreshold;
  const LocationPipelineConfig({
    this.enableSensorFusionFallback = true,
    this.gpsDropoutThreshold = const Duration(seconds: 8),
  });
}

class LocationCadence {
  final int distanceFilterMeters;
  final String accuracyProfile; // e.g., high|balanced|low
  const LocationCadence({required this.distanceFilterMeters, required this.accuracyProfile});
}

abstract class PowerModeController {
  Stream<PowerMode> get mode$;
  void ingest(LocationSample sample);
  PowerMode get currentMode;
}

abstract class DeviationEngine {
  /// Returns snapped position (may just echo raw with placeholder initially)
  SnappedPosition snap(LocationSample sample);
  /// Evaluates deviation classification.
  DeviationResult classify(LocationSample sample, SnappedPosition snapped);
  /// Optional suggested route switch routeId (null if none)
  String? evaluateRouteSwitch(SnappedPosition snapped);
  void resetOnRouteChange();
}

abstract class AlarmOrchestrator {
  Stream<AlarmEvent> get events$;
  void update({required LocationSample sample, required SnappedPosition? snapped});
  void configure(AlarmConfig config);
  void registerDestination(DestinationSpec spec);
  void reset();
}

class AlarmConfig {
  final double distanceThresholdMeters; // distance alarm radius
  final double timeETALimitSeconds; // time-based alarm threshold
  final int minEtaSamples;
  final double stopsThreshold; // for stops-based mode
  // Time eligibility gating overrides (to mirror legacy heuristics while allowing tests to relax them)
  final double minTimeEligibilityDistanceMeters; // movement required before ETA alarms considered
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

class DestinationSpec {
  final double lat;
  final double lng;
  final String name;
  const DestinationSpec({required this.lat, required this.lng, required this.name});
}

abstract class SessionStateStore {
  Future<void> save(SessionSnapshot snapshot);
  Future<SessionSnapshot?> load();
  Future<void> clear();
}

class SessionSnapshot {
  final String? activeRouteId;
  final double? progressMeters;
  final bool alarmEligible;
  final DateTime savedAt;
  const SessionSnapshot({
    required this.activeRouteId,
    required this.progressMeters,
    required this.alarmEligible,
    required this.savedAt,
  });
}

abstract class NotificationGateway {
  Future<void> showProgress({required double percent, required String title, String? subtitle});
  Future<void> showAlarm({required String title, required String body});
  Future<void> stopAlarm();
  Future<void> updatePowerMode(PowerMode mode);
}

abstract class TrackingSessionFacade {
  Future<void> start({required DestinationSpec destination, required AlarmConfig alarmConfig});
  Future<void> stop();
  Stream<AlarmEvent> get alarmEvents$;
  Stream<PowerMode> get powerMode$;
}
