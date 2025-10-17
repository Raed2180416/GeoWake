import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/route_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await RouteCache.clear();
  });

  test('RouteCache persists simplifiedCompressedPolyline (scp) field', () async {
    final origin = const LatLng(12.0, 77.0);
    final dest = const LatLng(12.5, 77.5);
    final key = RouteCache.makeKey(origin: origin, destination: dest, mode: 'driving');

    const scp = 'v1:compressed:polyline:string';
    await RouteCache.put(RouteCacheEntry(
      key: key,
      directions: {
        'status': 'OK',
        'routes': [
          {
            'overview_polyline': {'points': '}_se}Ff`miO??'},
            'simplified_polyline': scp,
          }
        ]
      },
      timestamp: DateTime.now(),
      origin: origin,
      destination: dest,
      mode: 'driving',
      simplifiedCompressedPolyline: scp,
    ));

    final entry = await RouteCache.get(origin: origin, destination: dest, mode: 'driving');
    expect(entry, isNotNull);
    expect(entry!.simplifiedCompressedPolyline, scp);
    // Also ensure directions payload still carries simplified_polyline for UI reuse
    final routes = (entry.directions['routes'] as List?) ?? const [];
    expect(routes, isNotEmpty);
    final route0 = routes.first as Map<String, dynamic>;
    expect(route0['simplified_polyline'], scp);
  });
}
