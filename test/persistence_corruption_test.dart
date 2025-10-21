import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:geowake2/services/persistence/persistence_manager.dart';

void main() {
  test('corrupted snapshot returns null', () async {
    final dir = await Directory.systemTemp.createTemp('gw_snap_corrupt');
    final pm = PersistenceManager(baseDir: dir);
    final file = File('${dir.path}/tracking_snapshot.json');
    await file.writeAsString('{not valid json');
    final loaded = await pm.load();
    expect(loaded, isNull);
  });
}
