import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';
import 'package:geowake2/services/route_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteCache capacity + corruption', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);
      await RouteCache.clear();
      // Lower maxEntries to a small number to exercise eviction deterministically
      RouteCache.maxEntries = 5;
    });

    tearDown(() async {
      await Hive.close();
      try { await tempDir.delete(recursive: true); } catch (_) {}
    });

    Future<RouteCacheEntry> _makeEntry(int idx) async {
      final origin = LatLng(37.42 + idx * 0.0001, -122.08);
      final dest = const LatLng(37.43, -122.18);
      final mode = 'driving';
      final key = RouteCache.makeKey(origin: origin, destination: dest, mode: mode);
      return RouteCacheEntry(
        key: key,
        directions: const {'routes': []},
        timestamp: DateTime.now().subtract(Duration(minutes: idx)), // older idx -> further in past
        origin: origin,
        destination: dest,
        mode: mode,
      );
    }

    test('Evicts oldest when capacity exceeded', () async {
      // Insert maxEntries entries
      final box = await Hive.openBox<String>(RouteCache.boxName);
      RouteCacheEntry? oldestEntry;
      for (int i = 0; i < RouteCache.maxEntries; i++) {
        final e = await _makeEntry(i + 1); // idx+1 minutes old
  if (oldestEntry == null || e.timestamp.isBefore(oldestEntry.timestamp)) {
          oldestEntry = e;
        }
        await RouteCache.put(e);
      }
      expect(box.length, RouteCache.maxEntries, reason: 'Should have reached capacity');
      expect(oldestEntry, isNotNull);
      final oldestKey = oldestEntry!.key;

      // Add one more newer entry (timestamp ~ now) -> should evict oldestKey
      final newest = RouteCacheEntry(
        key: RouteCache.makeKey(
          origin: const LatLng(37.50, -122.08),
          destination: const LatLng(37.51, -122.18),
          mode: 'driving',
        ),
        directions: const {'routes': []},
        timestamp: DateTime.now(),
        origin: const LatLng(37.50, -122.08),
        destination: const LatLng(37.51, -122.18),
        mode: 'driving',
      );
      await RouteCache.put(newest);
      expect(box.length, RouteCache.maxEntries);
      expect(box.get(oldestKey), isNull, reason: 'Oldest key should have been evicted');
      expect(box.get(newest.key), isNotNull, reason: 'Newest entry must remain');
    });

    test('TTL stale removal leaves newer entries intact', () async {
      final origin = const LatLng(37.4219999, -122.0840575);
      final dest = const LatLng(37.4275, -122.1697);
      final mode = 'driving';
      final stale = RouteCacheEntry(
        key: RouteCache.makeKey(origin: origin, destination: dest, mode: mode),
        directions: const {'routes': []},
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        origin: origin,
        destination: dest,
        mode: mode,
      );
      await RouteCache.put(stale);
      final freshEntry = RouteCacheEntry(
        key: RouteCache.makeKey(origin: const LatLng(37.422, -122.08405), destination: dest, mode: mode),
        directions: const {'routes': []},
        timestamp: DateTime.now(),
        origin: const LatLng(37.422, -122.08405),
        destination: dest,
        mode: mode,
      );
      await RouteCache.put(freshEntry);
      final gotStale = await RouteCache.get(
        origin: origin,
        destination: dest,
        mode: mode,
        ttl: const Duration(minutes: 5),
      );
      expect(gotStale, isNull);
      final gotFresh = await RouteCache.get(
        origin: freshEntry.origin,
        destination: freshEntry.destination,
        mode: freshEntry.mode,
        ttl: const Duration(minutes: 5),
      );
      expect(gotFresh, isNotNull);
    });

    test('Corrupted JSON entry auto-removed and returns null', () async {
      final origin = const LatLng(37.4219, -122.0840);
      final dest = const LatLng(37.4275, -122.1697);
      final key = RouteCache.makeKey(origin: origin, destination: dest, mode: 'driving');
      final box = await Hive.openBox<String>(RouteCache.boxName);
      await box.put(key, '{ bad-json');
      final fetched = await RouteCache.get(
        origin: origin,
        destination: dest,
        mode: 'driving',
      );
      expect(fetched, isNull);
      expect(box.get(key), isNull, reason: 'Corrupted entry should be deleted');
    });
  });
}
