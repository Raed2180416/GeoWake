/// Common DTOs shared across refactored tracking modules.

class LocationSample {
  final double lat;
  final double lng;
  final double speedMps;
  final DateTime timestamp;
  final double? accuracy;
  final double? heading;
  final double? altitude;
  LocationSample({
    required this.lat,
    required this.lng,
    required this.speedMps,
    required this.timestamp,
    this.accuracy,
    this.heading,
    this.altitude,
  });
}

class SnappedPosition {
  final double lat;
  final double lng;
  final String routeId;
  final double progressMeters;
  final double lateralOffsetMeters;
  final int segmentIndex;
  SnappedPosition({
    required this.lat,
    required this.lng,
    required this.routeId,
    required this.progressMeters,
    required this.lateralOffsetMeters,
    required this.segmentIndex,
  });
}

class DeviationResult {
  final bool isDeviating;
  final double lateralOffsetMeters;
  final String tier; // e.g., none|minor|major
  final DateTime observedAt;
  DeviationResult({
    required this.isDeviating,
    required this.lateralOffsetMeters,
    required this.tier,
    required this.observedAt,
  });
}

enum PowerMode { active, idle }

class AlarmEvent {
  final String type; // TRIGGERED, CANCELLED, ELIGIBILITY_CHANGED
  final DateTime at;
  final Map<String, dynamic> data;
  AlarmEvent(this.type, this.at, this.data);
}
