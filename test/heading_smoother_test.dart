import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/heading_smoother.dart';

void main() {
  group('HeadingSmoother', () {
    test('initial value passes through', () {
      final hs = HeadingSmoother();
      final t0 = DateTime.now();
      final h = hs.update(350, t0);
      expect(h, closeTo(350, 1e-6));
    });

    test('wrap-around shortest path (350 -> 10 should move +20 not -340)', () {
      final hs = HeadingSmoother(emaAlphaFast: 1.0, emaAlphaSlow: 1.0); // disable smoothing to expose logic
      final t0 = DateTime.now();
      hs.update(350, t0);
      final h2 = hs.update(10, t0.add(const Duration(milliseconds: 500)));
      // With alpha=1 and shortest diff +20 we land at 10 directly
      expect(h2, closeTo(10, 1e-6));
    });

    test('hairpin turn moderated (0 -> 180) limited by turn rate', () {
      final hs = HeadingSmoother(maxTurnRateDegPerSec: 90, emaAlphaSlow: 1.0, emaAlphaFast: 1.0);
      DateTime t = DateTime.now();
      hs.update(0, t);
      // After 1 second, max delta allowed 90 deg -> should not jump to 180
      t = t.add(const Duration(seconds: 1));
      final h1 = hs.update(180, t);
      expect(h1, inInclusiveRange(85, 95), reason: 'First second limited to ~90 deg');
      // Another second -> should approach 180 (another +90 => ~180)
      t = t.add(const Duration(seconds: 1));
      final h2 = hs.update(180, t);
      expect(h2, inInclusiveRange(170, 190));
    });

    test('idle reset after gap', () {
      final hs = HeadingSmoother(resetIfIdle: const Duration(milliseconds: 300));
      DateTime t = DateTime.now();
      hs.update(100, t);
      t = t.add(const Duration(milliseconds: 100));
      hs.update(110, t);
      t = t.add(const Duration(milliseconds: 400)); // idle gap triggers reset
      final h = hs.update(200, t);
      expect(h, closeTo(200, 1e-6)); // reset adopts new raw
    });
  });
}
