/// alarm_orchestrator.dart: Source file from lib/lib/services/alarm_orchestrator.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

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
  /// show: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> show(String title, String body, bool allowContinue);
  /// cancelProgress: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> cancelProgress();
}

/// DefaultAlarmNotifier: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class DefaultAlarmNotifier implements AlarmNotifier {
  @override
  /// show: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> show(String title, String body, bool allowContinue) => NotificationService().showWakeUpAlarm(
        title: title,
        body: body,
        allowContinueTracking: allowContinue,
      );
  @override
  /// cancelProgress: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> cancelProgress() => NotificationService().cancelJourneyProgress();
}

/// AlarmSoundPlayer: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
abstract class AlarmSoundPlayer {
  /// play: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> play();
}

/// DefaultAlarmSoundPlayer: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class DefaultAlarmSoundPlayer implements AlarmSoundPlayer {
  @override
  /// play: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> play() => AlarmPlayer.playSelected();
}

/// AlarmOrchestrator: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class AlarmOrchestrator {
  bool _fired = false;
  bool get fired => _fired;
  DateTime? _firedAt;
  DateTime? get firedAt => _firedAt;
  /// [Brief description of this field]
  final AlarmNotifier _notifier;
  /// [Brief description of this field]
  final AlarmSoundPlayer _sound;
  /// [Brief description of this field]
  final PendingAlarmStore _store;
  /// [Brief description of this field]
  final AlarmScheduler _scheduler;
  /// [Brief description of this field]
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
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_scheduledPending != null) return; // already scheduled in this instance
    // Try load from store in case process restarted
    /// load: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _scheduledPending ??= await _store.load();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_scheduledPending != null) return; // already persisted by prior run
    /// fallback: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final id = 9001; // reserved id for destination alarm fallback (TODO: configurable if multiple types later)
    /// now: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
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
    /// save: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await _store.save(pending);
    _scheduledPending = pending;
    try {
      /// scheduleExact: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _scheduler.scheduleExact(
        id: pending.id,
        triggerEpochMs: pending.triggerEpochMs,
        /// toJsonString: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        payload: pending.toJsonString(),
      );
      /// i: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.i('AlarmOrch', 'Scheduled fallback OS alarm id=${pending.id} at=${pending.triggerEpochMs}');
      EventBus().emit(AlarmScheduledEvent(pending.triggerEpochMs));
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e, st) {
      /// e: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.e('AlarmOrch', 'Failed scheduling fallback OS alarm', e, st);
    }
  }

  /// For restore paths: if a pending alarm exists in store but was not scheduled in this process yet,
  /// re-issue the platform schedule without altering persistence. No-op if nothing in store.
  Future<void> rescheduleExistingPendingIfAny() async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_scheduledPending != null) return; // already have in-memory
    /// load: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final loaded = await _store.load();
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (loaded == null) return;
    _scheduledPending = loaded; // attach to in-memory so later cancellation works
    try {
      /// scheduleExact: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _scheduler.scheduleExact(
        id: loaded.id,
        triggerEpochMs: loaded.triggerEpochMs,
        /// toJsonString: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        payload: loaded.toJsonString(),
      );
      /// i: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.i('AlarmOrch', 'Re-scheduled existing pending alarm id=${loaded.id} at=${loaded.triggerEpochMs}');
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e, st) {
      /// e: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.e('AlarmOrch', 'Failed to re-schedule existing pending', e, st);
    }
  }

  /// triggerDestinationAlarm: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> triggerDestinationAlarm({
    required String title,
    required String body,
    bool allowContinue = true,
  }) async {
    // Rollout gating: in shadow stage we do not surface any user-visible alarm.
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_rollout.stage == OrchestratorRolloutStage.shadow) {
      /// i: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.i('AlarmOrch', 'Rollout stage=shadow; suppressing destination alarm (shadow instrumentation only)');
      EventBus().emit(AlarmShadowSuppressedEvent());
      return;
    }
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_fired) {
      /// d: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.d('AlarmOrch', 'Destination alarm already fired; ignoring duplicate');
      return;
    }
    /// i: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    Log.i('AlarmOrch', 'Triggering destination alarm (phase1=notification)');
    try {
      /// show: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _notifier.show(title, body, allowContinue);
      EventBus().emit(AlarmFiredPhase1Event());
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e, st) {
      /// e: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.e('AlarmOrch', 'Notification phase failed', e, st);
      rethrow; // Nothing to rollback yet
    }
    // Phase 2: audio/vibration start. Only mark fired after both succeed.
    try {
      /// play: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _sound.play();
      _fired = true;
      /// now: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      _firedAt = DateTime.now();
      /// i: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.i('AlarmOrch', 'Alarm fully active (notification+audio)');
      EventBus().emit(AlarmFiredPhase2Event());
      // Cancel fallback if scheduled
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (_scheduledPending != null) {
        try {
          /// cancel: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          await _scheduler.cancel(_scheduledPending!.id);
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (_) {}
        /// clear: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await _store.clear();
        _scheduledPending = null;
      }
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e, st) {
      /// e: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      Log.e('AlarmOrch', 'Audio phase failed; attempting rollback', e, st);
      try {
        /// cancelProgress: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await _notifier.cancelProgress(); // best-effort cleanup
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (_) {}
      // Clear pending alarm preference flag so app does not think alarm is active.
      try {
        /// getInstance: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final prefs = await SharedPreferences.getInstance();
        /// remove: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await prefs.remove('pending_alarm_flag');
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (_) {}
      EventBus().emit(AlarmRollbackEvent());
      rethrow;
    }
  }

  /// reset: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void reset() {
    _fired = false;
    _firedAt = null;
    _scheduledPending = null;
  }
}
