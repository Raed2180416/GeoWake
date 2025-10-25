import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/event_bus.dart';
import 'package:geowake2/services/snap_to_route.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/alarm_orchestrator.dart';
import 'package:geowake2/services/alarm_rollout.dart';
import 'package:geowake2/services/alarm_scheduler.dart';
import 'package:geowake2/services/pending_alarm_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNotifier implements AlarmNotifier {
  @override
  Future<void> show(String title, String body, bool allowContinue) async {}
  @override
  Future<void> cancelProgress() async {}
}

class _MockSound implements AlarmSoundPlayer {
  bool fail = false; int plays=0;
  @override
  Future<void> play() async { plays++; if (fail) throw Exception('fail'); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventBus emissions', () {
    late List<DomainEvent> events;
    late StreamSubscription sub;

    setUp(() {
      events = [];
      sub = EventBus().stream.listen(events.add);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async { await sub.cancel(); });

    test('Teleport and backtrack events emitted', () async {
      final poly = [
        LatLng(0,0),
        LatLng(0,0.01),
        LatLng(0,0.02),
      ];
      // baseline snap
      final r1 = SnapToRouteEngine.snap(point: LatLng(0,0.0005), polyline: poly);
      // large jump far away triggers teleport
      final r2 = SnapToRouteEngine.snap(
        point: LatLng(0,0.5),
        polyline: poly,
        lastSnappedPoint: r1.snappedPoint,
        lastProgress: r1.progressMeters,
      );
      expect(r2.teleportDetected, true);
      // simulate backward progress (use point near start again with high lastProgress)
      SnapToRouteEngine.snap(
        point: LatLng(0,0.0004),
        polyline: poly,
        lastSnappedPoint: r2.snappedPoint,
        lastProgress: r1.progressMeters + 500, // artificially high
      );
      // allow microtask flush
      await Future.delayed(const Duration(milliseconds: 10));
      expect(events.where((e)=> e is TeleportDetectedEvent).length, greaterThanOrEqualTo(1));
      expect(events.where((e)=> e is BacktrackClampedEvent).length, greaterThanOrEqualTo(1));
    });

    test('Alarm events emitted for schedule + phases + rollback', () async {
      final scheduler = NoopAlarmScheduler();
      final orchestrator = AlarmOrchestrator(
        notifier: _MockNotifier(),
        sound: _MockSound(),
        scheduler: scheduler,
        store: PendingAlarmStore(),
        rollout: AlarmRolloutConfig()..setStage(OrchestratorRolloutStage.primary),
      );
      final trigger = DateTime.now().millisecondsSinceEpoch + 60000;
      await orchestrator.ensureScheduledFallback(triggerEpochMs: trigger, routeId: 'r1', targetLat: 0, targetLng: 0);
  await Future.delayed(const Duration(milliseconds: 5));
      expect(events.any((e)=> e is AlarmScheduledEvent), true);
      await orchestrator.triggerDestinationAlarm(title: 't', body: 'b');
  await Future.delayed(const Duration(milliseconds: 5));
      expect(events.any((e)=> e is AlarmFiredPhase1Event), true);
      expect(events.any((e)=> e is AlarmFiredPhase2Event), true);

      // rollback scenario
      final badSound = _MockSound()..fail=true;
      final orchestrator2 = AlarmOrchestrator(
        notifier: _MockNotifier(),
        sound: badSound,
        scheduler: scheduler,
        store: PendingAlarmStore(),
        rollout: AlarmRolloutConfig()..setStage(OrchestratorRolloutStage.primary),
      );
      final trigger2 = DateTime.now().millisecondsSinceEpoch + 60000;
      await orchestrator2.ensureScheduledFallback(triggerEpochMs: trigger2, routeId: 'r2', targetLat: 0, targetLng: 0);
  await Future.delayed(const Duration(milliseconds: 5));
      bool threw = false;
      try { await orchestrator2.triggerDestinationAlarm(title: 't2', body: 'b2'); } catch (_) { threw = true; }
      expect(threw, true);
  await Future.delayed(const Duration(milliseconds: 5));
      expect(events.any((e)=> e is AlarmRollbackEvent), true);
    });
  });
}
