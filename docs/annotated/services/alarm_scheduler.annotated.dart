/// alarm_scheduler.dart: Source file from lib/lib/services/alarm_scheduler.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:async';
import 'package:geowake2/services/log.dart';

/// AlarmScheduler: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class AlarmScheduler {
  /// scheduleExact: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> scheduleExact({required int id, required int triggerEpochMs, required String payload});
  /// cancel: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> cancel(int id);
}

/// NoopAlarmScheduler: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class NoopAlarmScheduler implements AlarmScheduler {
  /// [Brief description of this field]
  final List<Map<String, dynamic>> scheduled = [];
  /// [Brief description of this field]
  final List<int> cancelled = [];

  @override
  /// scheduleExact: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> scheduleExact({required int id, required int triggerEpochMs, required String payload}) async {
    /// d: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    Log.d('AlarmScheduler', 'NOOP schedule id=$id at=$triggerEpochMs payload=$payload');
    /// removeWhere: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    scheduled.removeWhere((e) => e['id'] == id);
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    scheduled.add({'id': id, 'at': triggerEpochMs, 'payload': payload});
  }

  @override
  /// cancel: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> cancel(int id) async {
    /// d: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    Log.d('AlarmScheduler', 'NOOP cancel id=$id');
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    cancelled.add(id);
    /// removeWhere: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    scheduled.removeWhere((e) => e['id'] == id);
  }
}

/// High-level fallback alarm manager that can sit atop a platform [AlarmScheduler].
/// It maintains a single fallback (id 9001) that fires if primary logic fails.
class FallbackAlarmManager {
  /// [Brief description of this field]
  static const int fallbackId = 9001;
  /// [Brief description of this field]
  final AlarmScheduler _platform;
  final DateTime Function() _now;
  int? _scheduledEpochMs;
  String? _reason;
  void Function(String reason)? onFire; // callback for tests/higher-level logic
  Timer? _testTimer; // only used in test mode

  /// [Brief description of this field]
  static bool isTestMode = false;
  /// [Brief description of this field]
  static final List<Map<String, dynamic>> testEvents = [];

  FallbackAlarmManager(this._platform, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  bool get hasScheduled => _scheduledEpochMs != null;
  String? get reason => _reason;

  /// Schedule fallback after [delay]. If an existing fallback is sooner, keep it.
  Future<void> schedule(Duration delay, {String reason = 'fallback'}) async {
    /// _now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final target = _now().add(delay).millisecondsSinceEpoch;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_scheduledEpochMs != null && _scheduledEpochMs! <= target) {
      return; // existing sooner or equal
    }
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await cancel();
    _scheduledEpochMs = target;
    _reason = reason;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (isTestMode) {
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      testEvents.add({'action': 'schedule', 'at': target, 'reason': reason, 'delayMs': delay.inMilliseconds});
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _testTimer?.cancel();
      _testTimer = Timer(delay, _fireInternal);
    } else {
      /// scheduleExact: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _platform.scheduleExact(id: fallbackId, triggerEpochMs: target, payload: reason);
    }
  }

  /// cancel: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> cancel({String reason = 'cancel'}) async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_scheduledEpochMs == null) return;
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (isTestMode) {
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      testEvents.add({'action': 'cancel', 'at': _now().millisecondsSinceEpoch, 'reason': reason});
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _testTimer?.cancel();
    } else {
      /// cancel: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _platform.cancel(fallbackId);
    }
    _scheduledEpochMs = null;
    _reason = null;
  }

  /// _fireInternal: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _fireInternal() {
    /// [Brief description of this field]
    final r = _reason ?? 'fallback';
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (isTestMode) {
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      testEvents.add({'action': 'fire', 'at': _now().millisecondsSinceEpoch, 'reason': r});
    }
    _scheduledEpochMs = null;
    _reason = null;
    /// call: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    onFire?.call(r);
  }

  /// dispose: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void dispose() {
    /// cancel: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _testTimer?.cancel();
  }
}