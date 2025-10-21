import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/alarm_deduplicator.dart';

void main() {
  group('AlarmDeduplicator', () {
    test('suppresses within TTL and allows after expiry', () async {
      DateTime now = DateTime(2025, 1, 1, 12, 0, 0);
      DateTime fakeNow() => now;
      final dedup = AlarmDeduplicator(ttl: const Duration(seconds: 5), now: fakeNow);

      // First fire should pass
      expect(dedup.shouldFire('A'), isTrue);
      // Immediate second fire suppressed
      expect(dedup.shouldFire('A'), isFalse);
      // Advance 4.9s still suppressed
      now = now.add(const Duration(milliseconds: 4900));
      expect(dedup.shouldFire('A'), isFalse);
      // Advance to just past TTL
      now = now.add(const Duration(milliseconds: 200));
      expect(dedup.shouldFire('A'), isTrue);

      // Different key unaffected
      expect(dedup.shouldFire('B'), isTrue);
      expect(dedup.shouldFire('B'), isFalse);

      dedup.reset();
      expect(dedup.shouldFire('A'), isTrue); // reset cleared state
    });
  });
}
