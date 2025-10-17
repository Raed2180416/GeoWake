import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/alarm_scheduler.dart';

class _TestPlatformScheduler implements AlarmScheduler {
  final List<Map<String, dynamic>> scheduled = [];
  final List<int> cancelled = [];
  @override
  Future<void> scheduleExact({required int id, required int triggerEpochMs, required String payload}) async {
    scheduled.removeWhere((e) => e['id'] == id);
    scheduled.add({'id': id, 'at': triggerEpochMs, 'payload': payload});
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.removeWhere((e) => e['id'] == id);
  }
}

void main() {
  group('FallbackAlarmManager', () {
    test('schedule earlier replaces later, later ignored', () async {
      final plat = _TestPlatformScheduler();
      final mgr = FallbackAlarmManager(plat, now: () => DateTime.fromMillisecondsSinceEpoch(0));

      await mgr.schedule(const Duration(minutes: 10), reason: 'initial');
      expect(plat.scheduled.single['payload'], 'initial');

      // Later schedule (longer delay) should be ignored
      await mgr.schedule(const Duration(minutes: 12), reason: 'later');
      expect(plat.scheduled.single['payload'], 'initial');

      // Earlier schedule should replace
      await mgr.schedule(const Duration(minutes: 5), reason: 'earlier');
      expect(plat.scheduled.single['payload'], 'earlier');
    });

    test('test mode timer fires callback', () async {
      FallbackAlarmManager.isTestMode = true;
      final plat = _TestPlatformScheduler();
      DateTime now = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime fakeNow() => now;
      final mgr = FallbackAlarmManager(plat, now: fakeNow);
      String? firedReason;
      mgr.onFire = (r) => firedReason = r;

      await mgr.schedule(const Duration(milliseconds: 100), reason: 'backup');
      // simulate time pass for test timer
      await Future.delayed(const Duration(milliseconds: 150));
      expect(firedReason, 'backup');
      expect(FallbackAlarmManager.testEvents.any((e) => e['action'] == 'fire'), isTrue);
      await mgr.cancel(); // no-op after fire
    });
  });
}
