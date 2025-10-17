import 'package:geowake2/services/alarm_orchestrator.dart';
import 'package:geowake2/services/pending_alarm_store.dart';
import 'package:geowake2/models/pending_alarm.dart';
import 'package:geowake2/services/log.dart';

/// Handles restoration of a previously scheduled fallback alarm when the app starts.
/// Decisions:
///  - If trigger time already passed (within grace) -> fire in-app immediately via orchestrator (notification+audio).
///  - If still in future -> re-schedule via orchestrator.ensureScheduledFallback (which re-persist if cleared).
class AlarmRestoreService {
  final PendingAlarmStore _store;
  final AlarmOrchestrator _orchestrator;
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
        _nowMs = nowProvider ?? (() => DateTime.now().millisecondsSinceEpoch);

  Future<void> restoreIfAny() async {
    PendingAlarm? pending = await _store.load();
    if (pending == null) return;
    final now = _nowMs();
    if (pending.triggerEpochMs <= now) {
      if (now - pending.triggerEpochMs <= _fireGraceMs) {
        Log.i('AlarmRestore', 'Pending alarm overdue within grace -> firing now');
        await _store.clear();
        // Fire minimal path: using orchestrator's trigger (will cancel fallback inside)
        try {
          await _orchestrator.triggerDestinationAlarm(
            title: 'Wake Up!',
            body: 'Approaching your destination',
            allowContinue: true,
          );
        } catch (e, st) {
          Log.e('AlarmRestore', 'Failed firing restored alarm', e, st);
        }
      } else {
        Log.i('AlarmRestore', 'Pending alarm stale beyond grace; clearing');
        await _store.clear();
      }
      return;
    }
    // Future: re-schedule (orchestrator will no-op if already scheduled in memory but we cleared memory after restart)
    Log.i('AlarmRestore', 'Re-scheduling future pending alarm at ${pending.triggerEpochMs}');
    await _orchestrator.rescheduleExistingPendingIfAny();
  }
}