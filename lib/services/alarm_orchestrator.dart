import 'dart:async';
import 'package:geowake2/services/notification_service.dart';
import 'package:geowake2/services/alarm_player.dart';
import 'package:geowake2/services/log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/models/pending_alarm.dart';
import 'package:geowake2/services/pending_alarm_store.dart';
import 'package:geowake2/services/alarm_scheduler.dart';
import 'package:geowake2/services/event_bus.dart';
import 'package:geowake2/services/alarm_rollout.dart';

/// Minimal abstraction layer to begin extracting alarm logic from trackingservice.
/// Currently delegates triggering only; future iterations will move threshold evaluation.
abstract class AlarmNotifier {
  Future<void> show(String title, String body, bool allowContinue);
  Future<void> cancelProgress();
}

class DefaultAlarmNotifier implements AlarmNotifier {
  @override
  Future<void> show(String title, String body, bool allowContinue) => NotificationService().showWakeUpAlarm(
        title: title,
        body: body,
        allowContinueTracking: allowContinue,
      );
  @override
  Future<void> cancelProgress() => NotificationService().cancelJourneyProgress();
}

abstract class AlarmSoundPlayer {
  Future<void> play();
}

class DefaultAlarmSoundPlayer implements AlarmSoundPlayer {
  @override
  Future<void> play() => AlarmPlayer.playSelected();
}

class AlarmOrchestrator {
  bool _fired = false;
  bool get fired => _fired;
  DateTime? _firedAt;
  DateTime? get firedAt => _firedAt;
  final AlarmNotifier _notifier;
  final AlarmSoundPlayer _sound;
  final PendingAlarmStore _store;
  final AlarmScheduler _scheduler;
  final AlarmRolloutConfig _rollout;
  PendingAlarm? _scheduledPending; // cached copy

  AlarmOrchestrator({
    AlarmNotifier? notifier,
    AlarmSoundPlayer? sound,
    PendingAlarmStore? store,
    AlarmScheduler? scheduler,
    AlarmRolloutConfig? rollout,
  })  : _notifier = notifier ?? DefaultAlarmNotifier(),
        _sound = sound ?? DefaultAlarmSoundPlayer(),
        _store = store ?? PendingAlarmStore(),
        _scheduler = scheduler ?? NoopAlarmScheduler(),
        _rollout = rollout ?? AlarmRolloutConfig();

  /// Schedule a fallback OS alarm before we actually trigger (pre-alarm phase). If one already exists, do nothing.
  /// [triggerEpochMs] should be an absolute UTC epoch ms timestamp for when the alarm must fire at the latest.
  Future<void> ensureScheduledFallback({
    required int triggerEpochMs,
    required String? routeId,
    required double targetLat,
    required double targetLng,
  }) async {
    if (_scheduledPending != null) return; // already scheduled in this instance
    // Try load from store in case process restarted
    _scheduledPending ??= await _store.load();
    if (_scheduledPending != null) return; // already persisted by prior run
    final id = 9001; // reserved id for destination alarm fallback (TODO: configurable if multiple types later)
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending = PendingAlarm(
      id: id,
      routeId: routeId,
      targetLat: targetLat,
      targetLng: targetLng,
      triggerEpochMs: triggerEpochMs,
      type: 'destination',
      createdAtEpochMs: now,
      state: 'scheduled',
    );
    await _store.save(pending);
    _scheduledPending = pending;
    try {
      await _scheduler.scheduleExact(
        id: pending.id,
        triggerEpochMs: pending.triggerEpochMs,
        payload: pending.toJsonString(),
      );
      Log.i('AlarmOrch', 'Scheduled fallback OS alarm id=${pending.id} at=${pending.triggerEpochMs}');
      EventBus().emit(AlarmScheduledEvent(pending.triggerEpochMs));
    } catch (e, st) {
      Log.e('AlarmOrch', 'Failed scheduling fallback OS alarm', e, st);
    }
  }

  /// For restore paths: if a pending alarm exists in store but was not scheduled in this process yet,
  /// re-issue the platform schedule without altering persistence. No-op if nothing in store.
  Future<void> rescheduleExistingPendingIfAny() async {
    if (_scheduledPending != null) return; // already have in-memory
    final loaded = await _store.load();
    if (loaded == null) return;
    _scheduledPending = loaded; // attach to in-memory so later cancellation works
    try {
      await _scheduler.scheduleExact(
        id: loaded.id,
        triggerEpochMs: loaded.triggerEpochMs,
        payload: loaded.toJsonString(),
      );
      Log.i('AlarmOrch', 'Re-scheduled existing pending alarm id=${loaded.id} at=${loaded.triggerEpochMs}');
    } catch (e, st) {
      Log.e('AlarmOrch', 'Failed to re-schedule existing pending', e, st);
    }
  }

  Future<void> triggerDestinationAlarm({
    required String title,
    required String body,
    bool allowContinue = true,
  }) async {
    // Rollout gating: in shadow stage we do not surface any user-visible alarm.
    if (_rollout.stage == OrchestratorRolloutStage.shadow) {
      Log.i('AlarmOrch', 'Rollout stage=shadow; suppressing destination alarm (shadow instrumentation only)');
      EventBus().emit(AlarmShadowSuppressedEvent());
      return;
    }
    if (_fired) {
      Log.d('AlarmOrch', 'Destination alarm already fired; ignoring duplicate');
      return;
    }
    Log.i('AlarmOrch', 'Triggering destination alarm (phase1=notification)');
    try {
      await _notifier.show(title, body, allowContinue);
      EventBus().emit(AlarmFiredPhase1Event());
    } catch (e, st) {
      Log.e('AlarmOrch', 'Notification phase failed', e, st);
      rethrow; // Nothing to rollback yet
    }
    // Phase 2: audio/vibration start. Only mark fired after both succeed.
    try {
      await _sound.play();
      _fired = true;
      _firedAt = DateTime.now();
      Log.i('AlarmOrch', 'Alarm fully active (notification+audio)');
      EventBus().emit(AlarmFiredPhase2Event());
      // Cancel fallback if scheduled
      if (_scheduledPending != null) {
        try {
          await _scheduler.cancel(_scheduledPending!.id);
        } catch (_) {}
        await _store.clear();
        _scheduledPending = null;
      }
    } catch (e, st) {
      Log.e('AlarmOrch', 'Audio phase failed; attempting rollback', e, st);
      try {
        await _notifier.cancelProgress(); // best-effort cleanup
      } catch (_) {}
      // Clear pending alarm preference flag so app does not think alarm is active.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_alarm_flag');
      } catch (_) {}
      EventBus().emit(AlarmRollbackEvent());
      rethrow;
    }
  }

  void reset() {
    _fired = false;
    _firedAt = null;
    _scheduledPending = null;
  }
}
