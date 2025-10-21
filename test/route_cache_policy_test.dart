import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geowake2/services/route_cache.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
	TestWidgetsFlutterBinding.ensureInitialized();

	group('RouteCache policy', () {
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

		test('serves fresh entry within TTL and small origin deviation', () async {
			final origin = const LatLng(37.4219999, -122.0840575);
			final dest = const LatLng(37.4275, -122.1697);
			final mode = 'driving';
			final key = RouteCache.makeKey(origin: origin, destination: dest, mode: mode);
			final entry = RouteCacheEntry(
				key: key,
				directions: const {'routes': []},
				timestamp: DateTime.now(),
				origin: origin,
				destination: dest,
				mode: mode,
			);
			await RouteCache.put(entry);

			final fetched = await RouteCache.get(
				origin: origin,
				destination: dest,
				mode: mode,
				ttl: const Duration(minutes: 5),
				originDeviationMeters: 300,
			);
			expect(fetched, isNotNull);
			expect(fetched!.key, key);
		});

		test('expires by TTL', () async {
			final origin = const LatLng(37.4219999, -122.0840575);
			final dest = const LatLng(37.4275, -122.1697);
			final mode = 'driving';
			final key = RouteCache.makeKey(origin: origin, destination: dest, mode: mode);
			final entry = RouteCacheEntry(
				key: key,
				directions: const {'routes': []},
				timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
				origin: origin,
				destination: dest,
				mode: mode,
			);
			await RouteCache.put(entry);

			final fetched = await RouteCache.get(
				origin: origin,
				destination: dest,
				mode: mode,
				ttl: const Duration(minutes: 5),
			);
			expect(fetched, isNull);
		});

		test('invalidates by origin deviation', () async {
			final origin0 = const LatLng(37.4219999, -122.0840575);
			final originFar = const LatLng(37.45, -122.18); // >300m away
			final dest = const LatLng(37.4275, -122.1697);
			final mode = 'driving';
			final key = RouteCache.makeKey(origin: origin0, destination: dest, mode: mode);
			final entry = RouteCacheEntry(
				key: key,
				directions: const {'routes': []},
				timestamp: DateTime.now(),
				origin: origin0,
				destination: dest,
				mode: mode,
			);
			await RouteCache.put(entry);

			final fetched = await RouteCache.get(
				origin: originFar,
				destination: dest,
				mode: mode,
				originDeviationMeters: 300,
			);
			expect(fetched, isNull);
		});

		test('tiered reuse cadence within TTL; no thrash', () async {
			final origin = const LatLng(37.4219999, -122.0840575);
			final dest = const LatLng(37.4275, -122.1697);
			final mode = 'driving';
			final key = RouteCache.makeKey(origin: origin, destination: dest, mode: mode);
			final entry = RouteCacheEntry(
				key: key,
				directions: const {'routes': []},
				timestamp: DateTime.now(),
				origin: origin,
				destination: dest,
				mode: mode,
			);
			await RouteCache.put(entry);

			// Repeated gets within TTL should always serve and not evict
			for (int i = 0; i < 5; i++) {
				final got = await RouteCache.get(
					origin: origin,
					destination: dest,
					mode: mode,
					ttl: const Duration(minutes: 5),
				);
				expect(got, isNotNull);
			}
			// Ensure key still present in box
			final box = await Hive.openBox<String>(RouteCache.boxName);
			expect(box.get(key), isNotNull);
		});
	});
}
