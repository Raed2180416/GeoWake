import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/models/pending_alarm.dart';

void main() {
  group('PendingAlarm', () {
    test('creates instance with all required fields', () {
      // When: Create a pending alarm
      final alarm = PendingAlarm(
        destinationLat: 12.9716,
        destinationLng: 77.5946,
        destinationName: 'Test Location',
        alarmMode: 'distance',
        alarmValue: 1.5,
        createdAt: DateTime(2025, 10, 21, 10, 30),
      );

      // Then: All fields should be set correctly
      expect(alarm.destinationLat, 12.9716);
      expect(alarm.destinationLng, 77.5946);
      expect(alarm.destinationName, 'Test Location');
      expect(alarm.alarmMode, 'distance');
      expect(alarm.alarmValue, 1.5);
      expect(alarm.createdAt, DateTime(2025, 10, 21, 10, 30));
    });

    test('toMap serializes all fields correctly', () {
      // Given: A pending alarm
      final alarm = PendingAlarm(
        destinationLat: 12.9716,
        destinationLng: 77.5946,
        destinationName: 'Test Location',
        alarmMode: 'time',
        alarmValue: 10.0,
        createdAt: DateTime(2025, 10, 21, 10, 30),
      );

      // When: Convert to map
      final map = alarm.toMap();

      // Then: Map should contain all fields with correct types
      expect(map['destinationLat'], 12.9716);
      expect(map['destinationLng'], 77.5946);
      expect(map['destinationName'], 'Test Location');
      expect(map['alarmMode'], 'time');
      expect(map['alarmValue'], 10.0);
      expect(map['createdAt'], isA<String>());
      expect(DateTime.parse(map['createdAt']), DateTime(2025, 10, 21, 10, 30));
    });

    test('fromMap deserializes all fields correctly', () {
      // Given: A map representation
      final map = {
        'destinationLat': 12.9716,
        'destinationLng': 77.5946,
        'destinationName': 'Test Location',
        'alarmMode': 'stops',
        'alarmValue': 2.0,
        'createdAt': '2025-10-21T10:30:00.000',
      };

      // When: Create from map
      final alarm = PendingAlarm.fromMap(map);

      // Then: All fields should be restored
      expect(alarm.destinationLat, 12.9716);
      expect(alarm.destinationLng, 77.5946);
      expect(alarm.destinationName, 'Test Location');
      expect(alarm.alarmMode, 'stops');
      expect(alarm.alarmValue, 2.0);
      expect(alarm.createdAt, DateTime(2025, 10, 21, 10, 30));
    });

    test('round-trip serialization preserves data', () {
      // Given: Original alarm
      final original = PendingAlarm(
        destinationLat: 12.9716,
        destinationLng: 77.5946,
        destinationName: 'Test Location',
        alarmMode: 'distance',
        alarmValue: 3.0,
        createdAt: DateTime(2025, 10, 21, 10, 30),
      );

      // When: Serialize and deserialize
      final map = original.toMap();
      final restored = PendingAlarm.fromMap(map);

      // Then: Data should be identical
      expect(restored.destinationLat, original.destinationLat);
      expect(restored.destinationLng, original.destinationLng);
      expect(restored.destinationName, original.destinationName);
      expect(restored.alarmMode, original.alarmMode);
      expect(restored.alarmValue, original.alarmValue);
      expect(restored.createdAt, original.createdAt);
    });

    test('handles edge case coordinates', () {
      // Test boundary coordinates
      final testCases = [
        {'lat': 90.0, 'lng': 180.0, 'name': 'North Pole'},
        {'lat': -90.0, 'lng': -180.0, 'name': 'South Pole'},
        {'lat': 0.0, 'lng': 0.0, 'name': 'Equator Prime Meridian'},
        {'lat': 12.9716, 'lng': 77.5946, 'name': 'Bangalore'},
      ];

      for (var testCase in testCases) {
        final alarm = PendingAlarm(
          destinationLat: testCase['lat'] as double,
          destinationLng: testCase['lng'] as double,
          destinationName: testCase['name'] as String,
          alarmMode: 'distance',
          alarmValue: 1.0,
          createdAt: DateTime.now(),
        );

        // Should create without errors
        expect(alarm.destinationLat, testCase['lat']);
        expect(alarm.destinationLng, testCase['lng']);
      }
    });

    test('handles different alarm modes', () {
      final modes = ['distance', 'time', 'stops'];

      for (var mode in modes) {
        final alarm = PendingAlarm(
          destinationLat: 12.9716,
          destinationLng: 77.5946,
          destinationName: 'Test',
          alarmMode: mode,
          alarmValue: 1.0,
          createdAt: DateTime.now(),
        );

        expect(alarm.alarmMode, mode);

        // Verify round-trip
        final restored = PendingAlarm.fromMap(alarm.toMap());
        expect(restored.alarmMode, mode);
      }
    });

    test('handles various alarm values', () {
      final testValues = [0.1, 0.5, 1.0, 5.0, 10.0, 100.0];

      for (var value in testValues) {
        final alarm = PendingAlarm(
          destinationLat: 12.9716,
          destinationLng: 77.5946,
          destinationName: 'Test',
          alarmMode: 'distance',
          alarmValue: value,
          createdAt: DateTime.now(),
        );

        expect(alarm.alarmValue, value);

        // Verify round-trip
        final restored = PendingAlarm.fromMap(alarm.toMap());
        expect(restored.alarmValue, value);
      }
    });

    test('handles empty destination name', () {
      // Some locations might have empty names
      final alarm = PendingAlarm(
        destinationLat: 12.9716,
        destinationLng: 77.5946,
        destinationName: '',
        alarmMode: 'distance',
        alarmValue: 1.0,
        createdAt: DateTime.now(),
      );

      expect(alarm.destinationName, '');

      // Verify round-trip
      final restored = PendingAlarm.fromMap(alarm.toMap());
      expect(restored.destinationName, '');
    });

    test('handles very long destination names', () {
      // Test with a very long destination name
      final longName = 'A' * 500;
      final alarm = PendingAlarm(
        destinationLat: 12.9716,
        destinationLng: 77.5946,
        destinationName: longName,
        alarmMode: 'distance',
        alarmValue: 1.0,
        createdAt: DateTime.now(),
      );

      expect(alarm.destinationName, longName);

      // Verify round-trip
      final restored = PendingAlarm.fromMap(alarm.toMap());
      expect(restored.destinationName, longName);
    });

    test('handles special characters in destination name', () {
      final specialNames = [
        'Café São Paulo',
        '北京市',
        'Москва',
        'New York, NY 10001',
        'Place d\'Italie',
        'Test & Test',
        'Test <Test>',
      ];

      for (var name in specialNames) {
        final alarm = PendingAlarm(
          destinationLat: 12.9716,
          destinationLng: 77.5946,
          destinationName: name,
          alarmMode: 'distance',
          alarmValue: 1.0,
          createdAt: DateTime.now(),
        );

        expect(alarm.destinationName, name);

        // Verify round-trip
        final restored = PendingAlarm.fromMap(alarm.toMap());
        expect(restored.destinationName, name);
      }
    });

    test('handles different datetime formats', () {
      final dates = [
        DateTime(2025, 1, 1),
        DateTime(2025, 12, 31, 23, 59, 59),
        DateTime.now(),
        DateTime.utc(2025, 6, 15, 12, 30),
      ];

      for (var date in dates) {
        final alarm = PendingAlarm(
          destinationLat: 12.9716,
          destinationLng: 77.5946,
          destinationName: 'Test',
          alarmMode: 'distance',
          alarmValue: 1.0,
          createdAt: date,
        );

        final restored = PendingAlarm.fromMap(alarm.toMap());
        // DateTime round-trip may lose some precision, but should be very close
        expect(
          restored.createdAt.difference(date).inSeconds.abs(),
          lessThan(2),
        );
      }
    });
  });
}
