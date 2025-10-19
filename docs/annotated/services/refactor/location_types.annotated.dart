/// Common DTOs shared across refactored tracking modules.

/// LocationSample: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class LocationSample {
  /// [Brief description of this field]
  final double lat;
  /// [Brief description of this field]
  final double lng;
  /// [Brief description of this field]
  final double speedMps;
  /// [Brief description of this field]
  final DateTime timestamp;
  /// [Brief description of this field]
  final double? accuracy;
  /// [Brief description of this field]
  final double? heading;
  /// [Brief description of this field]
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

/// SnappedPosition: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class SnappedPosition {
  /// [Brief description of this field]
  final double lat;
  /// [Brief description of this field]
  final double lng;
  /// [Brief description of this field]
  final String routeId;
  /// [Brief description of this field]
  final double progressMeters;
  /// [Brief description of this field]
  final double lateralOffsetMeters;
  /// [Brief description of this field]
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

/// DeviationResult: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class DeviationResult {
  /// [Brief description of this field]
  final bool isDeviating;
  /// [Brief description of this field]
  final double lateralOffsetMeters;
  /// [Brief description of this field]
  final String tier; // e.g., none|minor|major
  /// [Brief description of this field]
  final DateTime observedAt;
  DeviationResult({
    required this.isDeviating,
    required this.lateralOffsetMeters,
    required this.tier,
    required this.observedAt,
  });
}

enum PowerMode { active, idle }

/// AlarmEvent: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class AlarmEvent {
  /// [Brief description of this field]
  final String type; // TRIGGERED, CANCELLED, ELIGIBILITY_CHANGED
  /// [Brief description of this field]
  final DateTime at;
  /// [Brief description of this field]
  final Map<String, dynamic> data;
  AlarmEvent(this.type, this.at, this.data);
}
