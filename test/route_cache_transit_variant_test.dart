import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/route_cache.dart';
import 'package:hive/hive.dart';

void main() {
	TestWidgetsFlutterBinding.ensureInitialized();

	group('RouteCache transitVariant and corruption', () {
		late Directory tempDir;

		setUp(() async {
			tempDir = await Directory.systemTemp.createTemp('hive_test_');
			Hive.init(tempDir.path);
			await RouteCache.clear();
		});

		tearDown(() async {
			await Hive.close();
			try { await tempDir.delete(recursive: true); } catch (_) {}
		});

		test('separate keys for transitVariant vs non-variant', () async {
			final origin = const LatLng(12.34, 56.78);
			final dest = const LatLng(12.35, 56.79);

			final kDriving = RouteCache.makeKey(origin: origin, destination: dest, mode: 'driving');
			final kTransitRail = RouteCache.makeKey(origin: origin, destination: dest, mode: 'transit', transitVariant: 'rail');
			final kTransitBus = RouteCache.makeKey(origin: origin, destination: dest, mode: 'transit', transitVariant: 'bus');

			expect(kDriving != kTransitRail, isTrue);
			expect(kTransitRail != kTransitBus, isTrue);

			final eRail = RouteCacheEntry(
				key: kTransitRail,
				directions: const {'routes': []},
				timestamp: DateTime.now(),
				origin: origin,
				destination: dest,
				mode: 'transit',
			);
			await RouteCache.put(eRail);

			// Fetch with exact variant
			final gotRail = await RouteCache.get(origin: origin, destination: dest, mode: 'transit', transitVariant: 'rail');
			expect(gotRail, isNotNull);

			// Fetch with different or missing variant should miss
			final missBus = await RouteCache.get(origin: origin, destination: dest, mode: 'transit', transitVariant: 'bus');
			final missNoVar = await RouteCache.get(origin: origin, destination: dest, mode: 'transit');
			expect(missBus, isNull);
			expect(missNoVar, isNull);
		});

		test('corrupt entry purged on decode failure', () async {
			final origin = const LatLng(10.0, 20.0);
			final dest = const LatLng(11.0, 21.0);
			final key = RouteCache.makeKey(origin: origin, destination: dest, mode: 'driving');

			// Insert invalid JSON directly into the box
			final box = await Hive.openBox<String>(RouteCache.boxName);
			await box.put(key, 'not-json');

			// Access via RouteCache should return null and delete the key
			final got = await RouteCache.get(origin: origin, destination: dest, mode: 'driving');
			expect(got, isNull);
			expect(box.get(key), isNull);
		});
	});
}
