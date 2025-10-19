/// snapshot.dart: Source file from lib/lib/services/persistence/snapshot.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:convert';

/// Versioned tracking session snapshot persisted for recovery.
/// All time values are epoch milliseconds (UTC) to avoid TZ ambiguity.
class TrackingSnapshot {
  /// [Brief description of this field]
  static const currentVersion = 3;

  /// [Brief description of this field]
  final int version;
  /// [Brief description of this field]
  final int timestampMs; // write time
  /// [Brief description of this field]
  final double? progress0to1;
  /// [Brief description of this field]
  final double? etaSeconds;
  /// [Brief description of this field]
  final double distanceTravelledMeters;
  /// [Brief description of this field]
  final double? destinationLat;
  /// [Brief description of this field]
  final double? destinationLng;
  /// [Brief description of this field]
  final String? destinationName;
  /// [Brief description of this field]
  final String? activeRouteKey;
  /// [Brief description of this field]
  final int? fallbackScheduledEpochMs;
  /// [Brief description of this field]
  final int? lastDestinationAlarmAtMs;
  // v2 additions
  /// [Brief description of this field]
  final double? smoothedHeadingDeg;
  /// [Brief description of this field]
  final bool? timeEligible;
  // v3 additions
  /// [Brief description of this field]
  final Map<String, dynamic>? orchestratorState;

  TrackingSnapshot({
    required this.version,
    required this.timestampMs,
    required this.progress0to1,
    required this.etaSeconds,
    required this.distanceTravelledMeters,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationName,
    required this.activeRouteKey,
    required this.fallbackScheduledEpochMs,
    required this.lastDestinationAlarmAtMs,
    this.smoothedHeadingDeg,
    this.timeEligible,
    this.orchestratorState,
  });

  /// toJson: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Map<String, dynamic> toJson() => {
    'v': version,
    'ts': timestampMs,
    'p': progress0to1,
    'eta': etaSeconds,
    'dist': distanceTravelledMeters,
    'dLat': destinationLat,
    'dLng': destinationLng,
    'dName': destinationName,
    'route': activeRouteKey,
    'fb': fallbackScheduledEpochMs,
    'lastDestAlarm': lastDestinationAlarmAtMs,
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (smoothedHeadingDeg != null) 'hdg': smoothedHeadingDeg,
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (timeEligible != null) 'timeElig': timeEligible,
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (orchestratorState != null) 'orch': orchestratorState,
  };

  /// encode: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  String encode() => jsonEncode(toJson());

  /// decode: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static TrackingSnapshot? decode(String raw) {
    try {
      /// jsonDecode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final v = (m['v'] as int?) ?? 0;
      Map<String, dynamic>? orchState;
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (v == 1) {
        // Migrate v1 -> v2
        return TrackingSnapshot(
          version: 2,
          /// toInt: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          timestampMs: (m['ts'] as num?)?.toInt() ?? 0,
          /// toDouble: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          progress0to1: (m['p'] as num?)?.toDouble(),
          /// toDouble: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          etaSeconds: (m['eta'] as num?)?.toDouble(),
          /// toDouble: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          distanceTravelledMeters: (m['dist'] as num?)?.toDouble() ?? 0.0,
          /// toDouble: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          destinationLat: (m['dLat'] as num?)?.toDouble(),
          /// toDouble: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          destinationLng: (m['dLng'] as num?)?.toDouble(),
          destinationName: m['dName'] as String?,
          activeRouteKey: m['route'] as String?,
          /// toInt: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          fallbackScheduledEpochMs: (m['fb'] as num?)?.toInt(),
          /// toInt: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          lastDestinationAlarmAtMs: (m['lastDestAlarm'] as num?)?.toInt(),
          smoothedHeadingDeg: null,
          timeEligible: null,
          orchestratorState: null,
        );
      }
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (v <= 0 || v > currentVersion) {
        return null; // reject unsupported future or invalid
      }
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (v >= 3) {
        /// [Brief description of this field]
        final raw = m['orch'];
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (raw is Map) {
          /// map: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          orchState = raw.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      return TrackingSnapshot(
        version: v,
        /// toInt: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        timestampMs: (m['ts'] as num?)?.toInt() ?? 0,
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        progress0to1: (m['p'] as num?)?.toDouble(),
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        etaSeconds: (m['eta'] as num?)?.toDouble(),
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        distanceTravelledMeters: (m['dist'] as num?)?.toDouble() ?? 0.0,
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        destinationLat: (m['dLat'] as num?)?.toDouble(),
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        destinationLng: (m['dLng'] as num?)?.toDouble(),
        destinationName: m['dName'] as String?,
        activeRouteKey: m['route'] as String?,
        /// toInt: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        fallbackScheduledEpochMs: (m['fb'] as num?)?.toInt(),
        /// toInt: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        lastDestinationAlarmAtMs: (m['lastDestAlarm'] as num?)?.toInt(),
        /// toDouble: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        smoothedHeadingDeg: (m['hdg'] as num?)?.toDouble(),
        timeEligible: m['timeElig'] as bool?,
        orchestratorState: orchState,
      );
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {
      return null; // corruption or parse error
    }
  }
}

// NOTE: If we need to persist alarmMode/alarmValue in snapshots for more
// advanced recovery (e.g., reconstruct orchestrator state after process kill)
// we should introduce a v4 schema adding fields 'aMode' and 'aVal'. Existing
// recovery logic does not require these because we persist that minimal data
// in tracking_session.json separately for cold-start auto-resume.
