import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/alarm_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlarmPlayer', () {
    tearDown(() async {
      // Ensure player is stopped after each test
      try {
        await AlarmPlayer.stop();
      } catch (_) {
        // Ignore errors in teardown
      }
    });

    test('playSelected sets isPlaying to true even without audio plugin', () async {
      // Given: Fresh player state
      expect(AlarmPlayer.isPlaying.value, isFalse);

      // When: Play is called
      await AlarmPlayer.playSelected();

      // Then: isPlaying should be true (even if audio plugin is missing in tests)
      expect(AlarmPlayer.isPlaying.value, isTrue);
    });

    test('stop sets isPlaying to false', () async {
      // Given: Player is playing
      await AlarmPlayer.playSelected();
      expect(AlarmPlayer.isPlaying.value, isTrue);

      // When: Stop is called
      await AlarmPlayer.stop();

      // Then: isPlaying should be false
      expect(AlarmPlayer.isPlaying.value, isFalse);
    });

    test('multiple play calls do not crash', () async {
      // When: Play is called multiple times rapidly
      await AlarmPlayer.playSelected();
      await AlarmPlayer.playSelected();
      await AlarmPlayer.playSelected();

      // Then: Should not crash and isPlaying should be true
      expect(AlarmPlayer.isPlaying.value, isTrue);
    });

    test('multiple stop calls do not crash', () async {
      // Given: Player is playing
      await AlarmPlayer.playSelected();

      // When: Stop is called multiple times
      await AlarmPlayer.stop();
      await AlarmPlayer.stop();
      await AlarmPlayer.stop();

      // Then: Should not crash and isPlaying should be false
      expect(AlarmPlayer.isPlaying.value, isFalse);
    });

    test('stop without play does not crash', () async {
      // When: Stop is called without ever playing
      await AlarmPlayer.stop();

      // Then: Should not crash
      expect(AlarmPlayer.isPlaying.value, isFalse);
    });

    test('play after stop works correctly', () async {
      // Given: Player is played and stopped
      await AlarmPlayer.playSelected();
      await AlarmPlayer.stop();
      expect(AlarmPlayer.isPlaying.value, isFalse);

      // When: Play is called again
      await AlarmPlayer.playSelected();

      // Then: isPlaying should be true again
      expect(AlarmPlayer.isPlaying.value, isTrue);
    });

    test('isPlaying notifier updates listeners', () async {
      // Given: Listener attached to isPlaying
      var notificationCount = 0;
      void listener() {
        notificationCount++;
      }

      AlarmPlayer.isPlaying.addListener(listener);

      // When: Play and stop are called
      await AlarmPlayer.playSelected();
      await AlarmPlayer.stop();

      // Then: Listener should be notified (at least twice: true and false)
      expect(notificationCount, greaterThanOrEqualTo(2));

      // Cleanup
      AlarmPlayer.isPlaying.removeListener(listener);
    });
  });

  group('AlarmPlayer error handling', () {
    test('gracefully handles missing audio plugin', () async {
      // In test environment, audio plugin is not available
      // The code should handle this gracefully

      // When: Play is called without plugin
      await AlarmPlayer.playSelected();

      // Then: Should not crash and state should update
      expect(AlarmPlayer.isPlaying.value, isTrue);
    });

    test('gracefully handles missing SharedPreferences', () async {
      // In test environment, SharedPreferences may not be initialized
      // The code should fall back to default ringtone

      // When: Play is called
      await AlarmPlayer.playSelected();

      // Then: Should not crash
      expect(AlarmPlayer.isPlaying.value, isTrue);
    });
  });
}
