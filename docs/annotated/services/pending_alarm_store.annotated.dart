import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/models/pending_alarm.dart';

/// Storage abstraction for pending OS-level fallback alarms.
///
/// **Purpose**: Persists scheduled alarms to survive app restarts and device reboots.
/// When the OS alarm fires after the app was killed, this storage allows
/// reconstructing the alarm context.
///
/// **Storage mechanism**: Uses SharedPreferences for simplicity and speed
/// (alarm data is small and needs fast access)
///
/// **Versioning**: Includes version field to enable future migration if
/// PendingAlarm schema changes.
///
/// **Usage - Saving**:
/// ```dart
/// final store = PendingAlarmStore();
/// final alarm = PendingAlarm(
///   id: 9001,
///   targetLat: 37.123,
///   targetLng: -122.456,
///   triggerEpochMs: DateTime.now().add(Duration(minutes: 10)).millisecondsSinceEpoch,
///   type: 'destination',
///   state: 'scheduled',
/// );
/// await store.save(alarm);
/// ```
///
/// **Usage - Loading (on app restart)**:
/// ```dart
/// final store = PendingAlarmStore();
/// final alarm = await store.load();
/// if (alarm != null) {
///   // Reschedule OS alarm in case it was lost
///   await alarmScheduler.schedule(alarm);
/// }
/// ```
///
/// **Usage - Clearing (when alarm fires or is cancelled)**:
/// ```dart
/// await store.clear();
/// ```
///
/// **Thread safety**: SharedPreferences operations are async but not atomic.
/// Since GeoWake only schedules one fallback alarm at a time, race conditions
/// are unlikely. If multiple alarms are needed in future, add locking.
class PendingAlarmStore {
  /// SharedPreferences key for alarm data
  static const _key = 'pending_alarm_v1';
  
  /// SharedPreferences key for version number
  static const _versionKey = 'pending_alarm_version';
  
  /// Current schema version (increment when PendingAlarm structure changes)
  static const _version = 1;

  /// Saves a pending alarm to persistent storage
  /// 
  /// **Overwrites** any existing alarm (single-alarm model)
  /// 
  /// Throws if SharedPreferences is unavailable (should never happen in production)
  Future<void> save(PendingAlarm alarm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, _version);
    await prefs.setString(_key, alarm.toJsonString());
  }

  /// Loads the pending alarm from persistent storage
  /// 
  /// Returns null if:
  /// - No alarm was saved
  /// - Saved alarm has incompatible version (needs migration)
  /// - JSON is corrupted
  ///
  /// **Migration note**: If version mismatch is detected, returns null.
  /// This is safe since alarm is only valid for current session. Future
  /// versions could implement migration logic here.
  Future<PendingAlarm?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ver = prefs.getInt(_versionKey);
    if (ver != _version) return null; // Only migrate when needed in future
    return PendingAlarm.fromJsonString(prefs.getString(_key));
  }

  /// Clears the pending alarm from persistent storage
  /// 
  /// Call this when:
  /// - Alarm fires successfully
  /// - User cancels tracking
  /// - User reaches destination before alarm fires
  ///
  /// Safe to call even if no alarm exists (no-op)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_versionKey);
  }
}
