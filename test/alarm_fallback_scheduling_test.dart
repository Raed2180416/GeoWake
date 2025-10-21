import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/alarm_orchestrator.dart';
import 'package:geowake2/services/alarm_scheduler.dart';
import 'package:geowake2/services/pending_alarm_store.dart';
import 'package:geowake2/models/pending_alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geowake2/services/alarm_rollout.dart';

class _MockNotifier implements AlarmNotifier {
  int showCalls = 0;
  int cancelCalls = 0;
  @override
  Future<void> show(String title, String body, bool allowContinue) async { showCalls++; }
  @override
  Future<void> cancelProgress() async { cancelCalls++; }
}

class _MockSound implements AlarmSoundPlayer {
  int playCalls = 0;
  bool fail = false;
  @override
  Future<void> play() async { playCalls++; if (fail) throw Exception('sound fail'); }
}

class _MemStore extends PendingAlarmStore {
  PendingAlarm? _mem;
  @override
  Future<void> save(PendingAlarm alarm) async { _mem = alarm; }
  @override
  Future<PendingAlarm?> load() async => _mem;
  @override
  Future<void> clear() async { _mem = null; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alarm fallback scheduling', () {
    late NoopAlarmScheduler scheduler;
    late _MockNotifier notifier;
    late _MockSound sound;
    late _MemStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      scheduler = NoopAlarmScheduler();
      notifier = _MockNotifier();
      sound = _MockSound();
      store = _MemStore();
    });

    test('ensureScheduledFallback persists and schedules once', () async {
  final orch = AlarmOrchestrator(notifier: notifier, sound: sound, store: store, scheduler: scheduler, rollout: AlarmRolloutConfig()..setStage(OrchestratorRolloutStage.primary));
      final trigger = DateTime.now().millisecondsSinceEpoch + 30000;
      await orch.ensureScheduledFallback(triggerEpochMs: trigger, routeId: 'r1', targetLat: 1, targetLng: 2);
      expect(store._mem, isNotNull);
      expect(scheduler.scheduled.length, 1);
      // second call no duplicate
      await orch.ensureScheduledFallback(triggerEpochMs: trigger + 10000, routeId: 'r1', targetLat: 1, targetLng: 2);
      expect(scheduler.scheduled.length, 1);
    });

    test('triggerDestinationAlarm cancels fallback', () async {
  final orch = AlarmOrchestrator(notifier: notifier, sound: sound, store: store, scheduler: scheduler, rollout: AlarmRolloutConfig()..setStage(OrchestratorRolloutStage.primary));
      final trigger = DateTime.now().millisecondsSinceEpoch + 30000;
      await orch.ensureScheduledFallback(triggerEpochMs: trigger, routeId: 'r1', targetLat: 1, targetLng: 2);
      expect(scheduler.scheduled.length, 1);
      await orch.triggerDestinationAlarm(title: 't', body: 'b');
      expect(scheduler.scheduled.length, 0); // removed
      expect(scheduler.cancelled.single, 9001);
      expect(store._mem, isNull);
      expect(orch.fired, true);
    });

    test('audio failure does not cancel fallback (could still fire OS)', () async {
  final orch = AlarmOrchestrator(notifier: notifier, sound: sound, store: store, scheduler: scheduler, rollout: AlarmRolloutConfig()..setStage(OrchestratorRolloutStage.primary));
      final trigger = DateTime.now().millisecondsSinceEpoch + 30000;
      await orch.ensureScheduledFallback(triggerEpochMs: trigger, routeId: 'r1', targetLat: 1, targetLng: 2);
      sound.fail = true;
      try { await orch.triggerDestinationAlarm(title: 't', body: 'b'); } catch (_) {}
      // Should not mark fired, and fallback still exists (since we only cancel on success)
      expect(orch.fired, false);
      expect(scheduler.scheduled.length, 1);
      expect(store._mem, isNotNull);
    });
  });
}
