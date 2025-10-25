import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/models/pending_alarm.dart';
import 'package:geowake2/services/pending_alarm_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingAlarmStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and load round trip', () async {
      final store = PendingAlarmStore();
      final alarm = PendingAlarm(
        id: 42,
        routeId: 'r1',
        targetLat: 1.2345,
        targetLng: 9.8765,
        triggerEpochMs: DateTime.now().millisecondsSinceEpoch + 60000,
        type: 'destination',
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        state: 'scheduled',
      );
      await store.save(alarm);
      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded, equals(alarm));
    });

    test('clear removes stored alarm', () async {
      final store = PendingAlarmStore();
      final alarm = PendingAlarm(
        id: 1,
        routeId: null,
        targetLat: 0.0,
        targetLng: 0.0,
        triggerEpochMs: 123456,
        type: 'destination',
        createdAtEpochMs: 123000,
        state: 'scheduled',
      );
      await store.save(alarm);
      await store.clear();
      final loaded = await store.load();
      expect(loaded, isNull);
    });

    test('version mismatch returns null (future migration placeholder)', () async {
      final store = PendingAlarmStore();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pending_alarm_version', 999); // unsupported
      await prefs.setString('pending_alarm_v1', '{}');
      final loaded = await store.load();
      expect(loaded, isNull);
    });
  });
}
