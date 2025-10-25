import 'dart:convert';

/// Represents a scheduled fallback OS alarm we can restore after process death / reboot.
///
/// **Purpose**: Persistence model for scheduled alarms that need to survive
/// app process termination. When the app is killed by the system, the OS-level
/// alarm will still fire and can restore the alarm notification.
///
/// **Lifecycle**:
/// 1. Created when user starts tracking
/// 2. Saved to persistent storage (SharedPreferences/file)
/// 3. OS alarm scheduled via platform channel
/// 4. If app dies, OS alarm fires and loads this from storage
/// 5. Deleted when alarm fires or tracking stops
///
/// **States**:
/// - `scheduled`: Alarm is set and waiting
/// - `fired_in_app`: App fired the alarm (normal case)
/// - `fired_os`: OS fired the alarm (app was dead)
/// - `cancelled`: User stopped tracking before alarm fired
class PendingAlarm {
  /// Unique platform alarm id (used to cancel/identify alarm)
  /// Must be consistent across app restarts
  final int id;
  
  /// Active route identifier (if any)
  /// Used to restore route context if app was killed
  final String? routeId;
  
  /// Destination latitude (for context / validation)
  /// Allows verification that alarm is still relevant after restore
  final double targetLat;
  
  /// Destination longitude
  final double targetLng;
  
  /// When OS alarm should fire (UTC epoch milliseconds)
  /// OS will fire alarm at or after this time
  final int triggerEpochMs;
  
  /// Type of alarm - e.g. 'destination', 'transfer', 'boarding'
  /// Determines alarm behavior and notification content
  final String type;
  
  /// Creation timestamp (UTC epoch milliseconds)
  /// Used for debugging and determining alarm age
  final int createdAtEpochMs;
  
  /// Current state: scheduled | fired_in_app | fired_os | cancelled
  /// Tracks alarm lifecycle for debugging and preventing duplicates
  final String state;

  const PendingAlarm({
    required this.id,
    required this.routeId,
    required this.targetLat,
    required this.targetLng,
    required this.triggerEpochMs,
    required this.type,
    required this.createdAtEpochMs,
    required this.state,
  });

  /// Creates a copy with optional field overrides
  /// Useful for state transitions (scheduled -> fired, etc)
  PendingAlarm copyWith({
    int? id,
    String? routeId,
    double? targetLat,
    double? targetLng,
    int? triggerEpochMs,
    String? type,
    int? createdAtEpochMs,
    String? state,
  }) => PendingAlarm(
        id: id ?? this.id,
        routeId: routeId ?? this.routeId,
        targetLat: targetLat ?? this.targetLat,
        targetLng: targetLng ?? this.targetLng,
        triggerEpochMs: triggerEpochMs ?? this.triggerEpochMs,
        type: type ?? this.type,
        createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
        state: state ?? this.state,
      );

  /// Converts to JSON map for persistence
  Map<String, dynamic> toJson() => {
        'id': id,
        'routeId': routeId,
        'targetLat': targetLat,
        'targetLng': targetLng,
        'triggerEpochMs': triggerEpochMs,
        'type': type,
        'createdAtEpochMs': createdAtEpochMs,
        'state': state,
      };

  /// Creates PendingAlarm from JSON map (loaded from storage)
  static PendingAlarm fromJson(Map<String, dynamic> json) => PendingAlarm(
        id: json['id'] as int,
        routeId: json['routeId'] as String?,
        targetLat: (json['targetLat'] as num).toDouble(),
        targetLng: (json['targetLng'] as num).toDouble(),
        triggerEpochMs: json['triggerEpochMs'] as int,
        type: json['type'] as String,
        createdAtEpochMs: json['createdAtEpochMs'] as int,
        state: json['state'] as String,
      );

  /// Convenience: Serializes to JSON string
  /// Used when passing alarm data via platform channels
  String toJsonString() => jsonEncode(toJson());
  
  /// Convenience: Deserializes from JSON string
  /// Returns null if string is invalid or empty
  static PendingAlarm? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    return fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      other is PendingAlarm &&
      other.id == id &&
      other.routeId == routeId &&
      other.targetLat == targetLat &&
      other.targetLng == targetLng &&
      other.triggerEpochMs == triggerEpochMs &&
      other.type == type &&
      other.createdAtEpochMs == createdAtEpochMs &&
      other.state == state;

  @override
  int get hashCode => Object.hash(id, routeId, targetLat, targetLng, triggerEpochMs, type, createdAtEpochMs, state);

  @override
  String toString() => 'PendingAlarm(id=$id routeId=$routeId type=$type trigger=$triggerEpochMs state=$state)';
}
