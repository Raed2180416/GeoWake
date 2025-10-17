import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/alarm_restore_service.dart';
import 'package:geowake2/services/alarm_orchestrator.dart';
import 'package:geowake2/services/alarm_rollout.dart';
import 'package:geowake2/services/alarm_scheduler.dart';
import 'package:geowake2/services/pending_alarm_store.dart';
import 'package:geowake2/models/pending_alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStore extends PendingAlarmStore {
  PendingAlarm? mem;
  @override
  Future<void> save(PendingAlarm alarm) async { mem = alarm; }
  @override
  Future<PendingAlarm?> load() async => mem;
  @override
  Future<void> clear() async { mem = null; }
}

class _MockNotifier implements AlarmNotifier {
  int showCalls = 0;
  @override
  Future<void> show(String title, String body, bool allowContinue) async { showCalls++; }
  @override
  Future<void> cancelProgress() async {}
}

class _MockSound implements AlarmSoundPlayer {
  int playCalls = 0;
  @override
  Future<void> play() async { playCalls++; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlarmRestoreService', () {
    late _MemStore store;
    late NoopAlarmScheduler scheduler;
    late _MockNotifier notifier;
    late _MockSound sound;
    late AlarmOrchestrator orchestrator;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = _MemStore();
      scheduler = NoopAlarmScheduler();
      notifier = _MockNotifier();
      sound = _MockSound();
      orchestrator = AlarmOrchestrator(
        notifier: notifier,
        sound: sound,
        store: store,
        scheduler: scheduler,
        rollout: AlarmRolloutConfig()..setStage(OrchestratorRolloutStage.primary),
      );
    });

    test('future pending alarm re-schedules', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      store.mem = PendingAlarm(
        id: 9001,
        routeId: 'r1',
        targetLat: 1,
        targetLng: 2,
        triggerEpochMs: now + 60000,
        type: 'destination',
        createdAtEpochMs: now - 1000,
        state: 'scheduled',
      );
      final svc = AlarmRestoreService(orchestrator: orchestrator, store: store, nowProvider: () => now);
      await svc.restoreIfAny();
      expect(scheduler.scheduled.length, 1);
      expect(notifier.showCalls, 0);
      expect(sound.playCalls, 0);
    });

    test('overdue within grace fires immediately', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      store.mem = PendingAlarm(
        id: 9001,
        routeId: 'r1',
        targetLat: 1,
        targetLng: 2,
        triggerEpochMs: now - 30000, // overdue 30s
        type: 'destination',
        createdAtEpochMs: now - 60000,
        state: 'scheduled',
      );
      final svc = AlarmRestoreService(orchestrator: orchestrator, store: store, nowProvider: () => now, fireGraceMs: 60000);
      await svc.restoreIfAny();
      expect(notifier.showCalls, 1);
      expect(sound.playCalls, 1);
      expect(store.mem, isNull); // cleared
    });

    test('stale overdue beyond grace clears without firing', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      store.mem = PendingAlarm(
        id: 9001,
        routeId: 'r1',
        targetLat: 1,
        targetLng: 2,
        triggerEpochMs: now - 180000, // 3 minutes ago
        type: 'destination',
        createdAtEpochMs: now - 200000,
        state: 'scheduled',
      );
      final svc = AlarmRestoreService(orchestrator: orchestrator, store: store, nowProvider: () => now, fireGraceMs: 60000);
      await svc.restoreIfAny();
      expect(notifier.showCalls, 0);
      expect(sound.playCalls, 0);
      expect(store.mem, isNull);
    });
  });
}
