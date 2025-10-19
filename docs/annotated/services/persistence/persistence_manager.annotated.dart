/// persistence_manager.dart: Source file from lib/lib/services/persistence/persistence_manager.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:io';
import 'snapshot.dart';

/// Handles atomic persistence of tracking snapshots.
/// Strategy: write to <name>.tmp then rename to final file to avoid partials.
class PersistenceManager {
  /// [Brief description of this field]
  final Directory baseDir;
  /// [Brief description of this field]
  final String fileName;

  PersistenceManager({required this.baseDir, this.fileName = 'tracking_snapshot.json'});

  File get _file => File('${baseDir.path}/$fileName');
  File get _tmpFile => File('${baseDir.path}/$fileName.tmp');

  /// save: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> save(TrackingSnapshot snap) async {
    try {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!await baseDir.exists()) {
        /// create: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await baseDir.create(recursive: true);
      }
      /// writeAsString: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _tmpFile.writeAsString(snap.encode(), flush: true);
      // On some platforms a rename is atomic; we rely on that.
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (await _file.exists()) {
        /// delete: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await _file.delete();
      }
      /// rename: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await _tmpFile.rename(_file.path);
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {
      // Best effort; swallow errors (could add logging hook later)
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      try { if (await _tmpFile.exists()) await _tmpFile.delete(); } catch (_) {}
    }
  }

  /// load: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<TrackingSnapshot?> load() async {
    try {
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (!await _file.exists()) return null;
      /// readAsString: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final raw = await _file.readAsString();
      /// decode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      return TrackingSnapshot.decode(raw);
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {
      return null; // treat as no snapshot
    }
  }

  /// clear: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> clear() async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    try { if (await _file.exists()) await _file.delete(); } catch (_) {}
  }
}
