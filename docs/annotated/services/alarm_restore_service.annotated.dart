/// alarm_restore_service.dart: Source file from lib/lib/services/alarm_restore_service.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'package:geowake2/services/alarm_orchestrator.dart';
import 'package:geowake2/services/pending_alarm_store.dart';
import 'package:geowake2/models/pending_alarm.dart';
import 'package:geowake2/services/log.dart';

/// Handles restoration of a previously scheduled fallback alarm when the app starts.
/// Decisions:
///  - If trigger time already passed (within grace) -> fire in-app immediately via orchestrator (notification+audio).
///  - If still in future -> re-schedule via orchestrator.ensureScheduledFallback (which re-persist if cleared).
class AlarmRestoreService {
  /// [Brief description of this field]
  final PendingAlarmStore _store;
  /// [Brief description of this field]
  final AlarmOrchestrator _orchestrator;
  /// [Brief description of this field]
  final int _fireGraceMs; // window within which we treat missed trigger as immediate fire
  final int Function() _nowMs;

  AlarmRestoreService({
    PendingAlarmStore? store,
    required AlarmOrchestrator orchestrator,
    int fireGraceMs = 120000, // 2 minutes grace
    int Function()? nowProvider,
  })  : _store = store ?? PendingAlarmStore(),
        _orchestrator = orchestrator,
        _fireGraceMs = fireGraceMs,
        /// now: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        _nowMs = nowProvider ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// restoreIfAny: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> restoreIfAny() async {
    /// load: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    PendingAlarm? pending = await _store.load();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (pending == null) return;
    /// _nowMs: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final now = _nowMs();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (pending.triggerEpochMs <= now) {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (now - pending.triggerEpochMs <= _fireGraceMs) {
        /// i: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        Log.i('AlarmRestore', 'Pending alarm overdue within grace -> firing now');
        /// clear: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await _store.clear();
        // Fire minimal path: using orchestrator's trigger (will cancel fallback inside)
        try {
          /// triggerDestinationAlarm: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          await _orchestrator.triggerDestinationAlarm(
            title: 'Wake Up!',
            body: 'Approaching your destination',
            allowContinue: true,
          );
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (e, st) {
          /// e: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          Log.e('AlarmRestore', 'Failed firing restored alarm', e, st);
        }
      } else {
        /// i: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        Log.i('AlarmRestore', 'Pending alarm stale beyond grace; clearing');
        /// clear: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await _store.clear();
      }
      return;
    }
    // Future: re-schedule (orchestrator will no-op if already scheduled in memory but we cleared memory after restart)
    /// i: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    Log.i('AlarmRestore', 'Re-scheduling future pending alarm at ${pending.triggerEpochMs}');
    /// rescheduleExistingPendingIfAny: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await _orchestrator.rescheduleExistingPendingIfAny();
  }
}