import 'dart:io';
import 'snapshot.dart';

/// Handles atomic persistence of tracking snapshots.
/// Strategy: write to <name>.tmp then rename to final file to avoid partials.
class PersistenceManager {
  final Directory baseDir;
  final String fileName;

  PersistenceManager({required this.baseDir, this.fileName = 'tracking_snapshot.json'});

  File get _file => File('${baseDir.path}/$fileName');
  File get _tmpFile => File('${baseDir.path}/$fileName.tmp');

  Future<void> save(TrackingSnapshot snap) async {
    try {
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }
      await _tmpFile.writeAsString(snap.encode(), flush: true);
      // On some platforms a rename is atomic; we rely on that.
      if (await _file.exists()) {
        await _file.delete();
      }
      await _tmpFile.rename(_file.path);
    } catch (_) {
      // Best effort; swallow errors (could add logging hook later)
      try { if (await _tmpFile.exists()) await _tmpFile.delete(); } catch (_) {}
    }
  }

  Future<TrackingSnapshot?> load() async {
    try {
      if (!await _file.exists()) return null;
      final raw = await _file.readAsString();
      return TrackingSnapshot.decode(raw);
    } catch (_) {
      return null; // treat as no snapshot
    }
  }

  Future<void> clear() async {
    try { if (await _file.exists()) await _file.delete(); } catch (_) {}
  }
}
