import 'dart:convert';

/// Versioned tracking session snapshot persisted for recovery.
/// All time values are epoch milliseconds (UTC) to avoid TZ ambiguity.
class TrackingSnapshot {
  static const currentVersion = 3;

  final int version;
  final int timestampMs; // write time
  final double? progress0to1;
  final double? etaSeconds;
  final double distanceTravelledMeters;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;
  final String? activeRouteKey;
  final int? fallbackScheduledEpochMs;
  final int? lastDestinationAlarmAtMs;
  // v2 additions
  final double? smoothedHeadingDeg;
  final bool? timeEligible;
  // v3 additions
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
    if (smoothedHeadingDeg != null) 'hdg': smoothedHeadingDeg,
    if (timeEligible != null) 'timeElig': timeEligible,
    if (orchestratorState != null) 'orch': orchestratorState,
  };

  String encode() => jsonEncode(toJson());

  static TrackingSnapshot? decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final v = (m['v'] as int?) ?? 0;
      Map<String, dynamic>? orchState;
      if (v == 1) {
        // Migrate v1 -> v2
        return TrackingSnapshot(
          version: 2,
          timestampMs: (m['ts'] as num?)?.toInt() ?? 0,
          progress0to1: (m['p'] as num?)?.toDouble(),
          etaSeconds: (m['eta'] as num?)?.toDouble(),
          distanceTravelledMeters: (m['dist'] as num?)?.toDouble() ?? 0.0,
          destinationLat: (m['dLat'] as num?)?.toDouble(),
          destinationLng: (m['dLng'] as num?)?.toDouble(),
          destinationName: m['dName'] as String?,
          activeRouteKey: m['route'] as String?,
          fallbackScheduledEpochMs: (m['fb'] as num?)?.toInt(),
          lastDestinationAlarmAtMs: (m['lastDestAlarm'] as num?)?.toInt(),
          smoothedHeadingDeg: null,
          timeEligible: null,
          orchestratorState: null,
        );
      }
      if (v <= 0 || v > currentVersion) {
        return null; // reject unsupported future or invalid
      }
      if (v >= 3) {
        final raw = m['orch'];
        if (raw is Map) {
          orchState = raw.map((key, value) => MapEntry(key.toString(), value));
        }
      }
      return TrackingSnapshot(
        version: v,
        timestampMs: (m['ts'] as num?)?.toInt() ?? 0,
        progress0to1: (m['p'] as num?)?.toDouble(),
        etaSeconds: (m['eta'] as num?)?.toDouble(),
        distanceTravelledMeters: (m['dist'] as num?)?.toDouble() ?? 0.0,
        destinationLat: (m['dLat'] as num?)?.toDouble(),
        destinationLng: (m['dLng'] as num?)?.toDouble(),
        destinationName: m['dName'] as String?,
        activeRouteKey: m['route'] as String?,
        fallbackScheduledEpochMs: (m['fb'] as num?)?.toInt(),
        lastDestinationAlarmAtMs: (m['lastDestAlarm'] as num?)?.toInt(),
        smoothedHeadingDeg: (m['hdg'] as num?)?.toDouble(),
        timeEligible: m['timeElig'] as bool?,
        orchestratorState: orchState,
      );
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
