import 'dart:async';
import 'package:geowake2/services/log.dart';

abstract class AlarmScheduler {
  Future<void> scheduleExact({required int id, required int triggerEpochMs, required String payload});
  Future<void> cancel(int id);
}

class NoopAlarmScheduler implements AlarmScheduler {
  final List<Map<String, dynamic>> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleExact({required int id, required int triggerEpochMs, required String payload}) async {
    Log.d('AlarmScheduler', 'NOOP schedule id=$id at=$triggerEpochMs payload=$payload');
    scheduled.removeWhere((e) => e['id'] == id);
    scheduled.add({'id': id, 'at': triggerEpochMs, 'payload': payload});
  }

  @override
  Future<void> cancel(int id) async {
    Log.d('AlarmScheduler', 'NOOP cancel id=$id');
    cancelled.add(id);
    scheduled.removeWhere((e) => e['id'] == id);
  }
}

/// High-level fallback alarm manager that can sit atop a platform [AlarmScheduler].
/// It maintains a single fallback (id 9001) that fires if primary logic fails.
class FallbackAlarmManager {
  static const int fallbackId = 9001;
  final AlarmScheduler _platform;
  final DateTime Function() _now;
  int? _scheduledEpochMs;
  String? _reason;
  void Function(String reason)? onFire; // callback for tests/higher-level logic
  Timer? _testTimer; // only used in test mode

  static bool isTestMode = false;
  static final List<Map<String, dynamic>> testEvents = [];

  FallbackAlarmManager(this._platform, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  bool get hasScheduled => _scheduledEpochMs != null;
  String? get reason => _reason;

  /// Schedule fallback after [delay]. If an existing fallback is sooner, keep it.
  Future<void> schedule(Duration delay, {String reason = 'fallback'}) async {
    final target = _now().add(delay).millisecondsSinceEpoch;
    if (_scheduledEpochMs != null && _scheduledEpochMs! <= target) {
      return; // existing sooner or equal
    }
    await cancel();
    _scheduledEpochMs = target;
    _reason = reason;
    if (isTestMode) {
      testEvents.add({'action': 'schedule', 'at': target, 'reason': reason, 'delayMs': delay.inMilliseconds});
      _testTimer?.cancel();
      _testTimer = Timer(delay, _fireInternal);
    } else {
      await _platform.scheduleExact(id: fallbackId, triggerEpochMs: target, payload: reason);
    }
  }

  Future<void> cancel({String reason = 'cancel'}) async {
    if (_scheduledEpochMs == null) return;
    if (isTestMode) {
      testEvents.add({'action': 'cancel', 'at': _now().millisecondsSinceEpoch, 'reason': reason});
      _testTimer?.cancel();
    } else {
      await _platform.cancel(fallbackId);
    }
    _scheduledEpochMs = null;
    _reason = null;
  }

  void _fireInternal() {
    final r = _reason ?? 'fallback';
    if (isTestMode) {
      testEvents.add({'action': 'fire', 'at': _now().millisecondsSinceEpoch, 'reason': r});
    }
    _scheduledEpochMs = null;
    _reason = null;
    onFire?.call(r);
  }

  void dispose() {
    _testTimer?.cancel();
  }
}