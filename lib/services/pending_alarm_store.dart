import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/models/pending_alarm.dart';

/// Storage abstraction for pending OS-level fallback alarms.
class PendingAlarmStore {
  static const _key = 'pending_alarm_v1';
  static const _versionKey = 'pending_alarm_version';
  static const _version = 1;

  Future<void> save(PendingAlarm alarm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey, _version);
    await prefs.setString(_key, alarm.toJsonString());
  }

  Future<PendingAlarm?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ver = prefs.getInt(_versionKey);
    if (ver != _version) return null; // Only migrate when needed in future
    return PendingAlarm.fromJsonString(prefs.getString(_key));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_versionKey);
  }
}
