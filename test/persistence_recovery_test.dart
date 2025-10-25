import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/persistence/snapshot.dart';
import 'package:geowake2/services/persistence/persistence_manager.dart';

void main() {
  test('snapshot save & load roundtrip', () async {
    final dir = await Directory.systemTemp.createTemp('gw_snap_test');
    final pm = PersistenceManager(baseDir: dir);
    final snap = TrackingSnapshot(
      version: TrackingSnapshot.currentVersion,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      progress0to1: 0.42,
      etaSeconds: 120.5,
      distanceTravelledMeters: 950.0,
      destinationLat: 12.34,
      destinationLng: 56.78,
      destinationName: 'Dest',
      activeRouteKey: 'r1',
      fallbackScheduledEpochMs: 1234567890,
      lastDestinationAlarmAtMs: null,
    );
    await pm.save(snap);
    final loaded = await pm.load();
    expect(loaded, isNotNull);
    expect(loaded!.progress0to1, closeTo(0.42, 1e-6));
    expect(loaded.activeRouteKey, 'r1');
  });
}
