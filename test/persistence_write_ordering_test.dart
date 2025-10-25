import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/persistence/persistence_manager.dart';
import 'package:geowake2/services/persistence/snapshot.dart';

void main() {
  test('latest snapshot wins under rapid writes', () async {
    final dir = await Directory.systemTemp.createTemp('gw_snap_order');
    final pm = PersistenceManager(baseDir: dir);

    for (int i=0;i<5;i++) {
      final snap = TrackingSnapshot(
        version: 1,
        timestampMs: 1000 + i,
        progress0to1: i / 4.0,
        etaSeconds: (100 - i).toDouble(),
        distanceTravelledMeters: (i * 10).toDouble(),
        destinationLat: 1.0,
        destinationLng: 2.0,
        destinationName: 'D',
        activeRouteKey: 'r',
        fallbackScheduledEpochMs: 0,
        lastDestinationAlarmAtMs: 0,
      );
      await pm.save(snap);
    }
    final loaded = await pm.load();
    expect(loaded, isNotNull);
    // Expect last timestamp
  expect(loaded!.timestampMs, 1004);
  expect(loaded.progress0to1, 1.0);
  });
}
