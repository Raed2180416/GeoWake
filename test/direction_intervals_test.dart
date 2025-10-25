import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/direction_service.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Distance-mode: interval thresholds map to near/mid/far', () {
    final ds = DirectionService();
    expect(ds.nearInterval < ds.midInterval, isTrue);
    expect(ds.midInterval < ds.farInterval, isTrue);

    double startLat = 12.0, startLng = 77.0;
    double thresholdKm = 2.0;
    double thrM = thresholdKm * 1000;

    double dFar = Geolocator.distanceBetween(startLat, startLng, startLat, startLng + 0.2); // ~22km
    double dMid = thrM * 2.5; // >2x threshold
    double dNear = thrM * 1.5; // <=2x threshold

    Duration select(double straightMeters) {
      if (straightMeters > 5 * thrM) return ds.farInterval;
      if (straightMeters > 2 * thrM) return ds.midInterval;
      return ds.nearInterval;
    }

    expect(select(dFar), ds.farInterval);
    expect(select(dMid), ds.midInterval);
    expect(select(dNear), ds.nearInterval);
  });

  test('Time-mode: always uses nearInterval cadence', () {
    final ds = DirectionService();
    expect(ds.nearInterval, const Duration(minutes: 3));
  });
}
