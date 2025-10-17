import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/route_cache.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
	TestWidgetsFlutterBinding.ensureInitialized();

		group('DirectionService caching (via RouteCache smoke)', () {
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

		test('RouteCache stores and retrieves with stable key rounding', () async {
			final originA = const LatLng(37.4219999, -122.0840575);
			// Slightly different origin should round to same key (5 decimals)
			final originB = const LatLng(37.4220001, -122.0840576);
			final dest = const LatLng(37.4275, -122.1697);
			final mode = 'driving';
			final keyA = RouteCache.makeKey(origin: originA, destination: dest, mode: mode);
			final keyB = RouteCache.makeKey(origin: originB, destination: dest, mode: mode);
			expect(keyA, keyB);

			await RouteCache.put(RouteCacheEntry(
				key: keyA,
				directions: const {'routes': []},
				timestamp: DateTime.now(),
				origin: originA,
				destination: dest,
				mode: mode,
			));

			final fetched = await RouteCache.get(origin: originB, destination: dest, mode: mode);
			expect(fetched, isNotNull);
			expect(fetched!.key, keyA);
		});
	});
}
