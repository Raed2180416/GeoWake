import 'dart:convert';

/// Represents a scheduled fallback OS alarm we can restore after process death / reboot.
class PendingAlarm {
  final int id; // Unique platform alarm id
  final String? routeId; // Active route identifier (if any)
  final double targetLat; // Destination lat (for context / validation)
  final double targetLng; // Destination lng
  final int triggerEpochMs; // When OS alarm should fire (UTC epoch ms)
  final String type; // e.g. 'destination'
  final int createdAtEpochMs; // Creation timestamp (UTC epoch ms)
  final String state; // scheduled | fired_in_app | fired_os | cancelled

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

  String toJsonString() => jsonEncode(toJson());
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
