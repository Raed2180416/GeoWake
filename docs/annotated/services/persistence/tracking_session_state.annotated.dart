/// tracking_session_state.dart: Source file from lib/lib/services/persistence/tracking_session_state.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight foreground-side persistence of the currently requested tracking
/// session (destination + alarm parameters). This is separate from the more
/// detailed periodic [TrackingSnapshot] which is written from the background
/// isolate. We keep this file tiny so we can quickly decide on cold start if
/// we should auto-resume tracking.
///
/// File format (JSON):
/// {
///   "destinationLat": <double>,
///   "destinationLng": <double>,
///   "destinationName": <String>,
///   "alarmMode": "distance" | "time" | "stops",
///   "alarmValue": <double>,
///   "startedAt": <epochMs>
/// }
class TrackingSessionStateFile {
  /// [Brief description of this field]
  static const _filename = 'tracking_session.json';
  /// [Brief description of this field]
  static const _prefsKey = 'tracking_session_json_v1';
  // New lightweight boolean flag to allow ultra-fast auto-resume checks
  /// [Brief description of this field]
  static const trackingActiveFlagKey = 'tracking_active_v1';

  /// _candidateFiles: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static Future<List<File>> _candidateFiles() async {
    /// [Brief description of this field]
    final files = <File>[];
    try {
      /// getApplicationSupportDirectory: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final appSupport = await getApplicationSupportDirectory();
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      files.add(File('${appSupport.path}/$_filename'));
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
    try {
      /// getApplicationDocumentsDirectory: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final docs = await getApplicationDocumentsDirectory();
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      files.add(File('${docs.path}/$_filename'));
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (_) {}
    // (Optional) external storage dir (Android only) not added to avoid extra permission complexity.
    return files;
  }

  /// save: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static Future<void> save(Map<String, dynamic> data) async {
    try {
      /// jsonEncode: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final jsonStr = jsonEncode(data);
      /// [Brief description of this field]
      final len = jsonStr.length;
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      dev.log('SessionState: save start (len=$len)', name: 'TrackingSession');
      // Stdout prints (prefixed) so they appear even if dev.log is filtered
      // Unique token: GW_ARES (GeoWake Auto RESume)
      // DO NOT REMOVE: Used for field diagnostics when dev.log signals missing.
      // Using print instead of debugPrint to avoid throttling and ensure logcat visibility.
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_SESSION_SAVE len=$len');
      /// _candidateFiles: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final candidates = await _candidateFiles();
      /// for: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      for (final f in candidates) {
        try {
          /// writeAsString: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          await f.writeAsString(jsonStr, flush: true);
          /// exists: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final exists = await f.exists();
          /// length: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final sz = exists ? (await f.length()) : -1;
            /// log: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            dev.log('SessionState: saved to ${f.path} size=$sz', name: 'TrackingSession');
            /// print: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            print('GW_ARES_SESSION_FILE_WRITE path=${f.path} size=$sz');
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (e) {
          /// log: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          dev.log('SessionState: write failed to ${f.path} $e', name: 'TrackingSession');
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_SESSION_FILE_WRITE_FAIL path=${f.path} err=$e');
        }
      }
      // Always persist to SharedPreferences as well for resilience.
      try {
        /// getInstance: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final prefs = await SharedPreferences.getInstance();
        /// setString: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await prefs.setString(_prefsKey, jsonStr);
        /// setBool: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await prefs.setBool(trackingActiveFlagKey, true);
        /// log: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        dev.log('SessionState: saved to SharedPreferences (redundant)', name: 'TrackingSession');
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_ARES_SESSION_PREFS_WRITE ok jsonLen=$len');
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) {
        /// log: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        dev.log('SessionState: prefs write failed $e', name: 'TrackingSession');
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_ARES_SESSION_PREFS_WRITE_FAIL err=$e');
      }
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      dev.log('SessionState: save exception $e', name: 'TrackingSession');
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_SESSION_SAVE_EXCEPTION err=$e');
    }
  }

  /// load: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static Future<Map<String, dynamic>?> load() async {
    try {
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_SESSION_LOAD_START');
      /// _candidateFiles: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final candidates = await _candidateFiles();
      /// for: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      for (final f in candidates) {
        try {
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (await f.exists()) {
            /// length: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            final len = await f.length();
            /// readAsString: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            final raw = await f.readAsString();
            /// log: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            dev.log('SessionState: candidate ${f.path} exists len=$len', name: 'TrackingSession');
            /// jsonDecode: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            final m = jsonDecode(raw) as Map<String, dynamic>;
            /// log: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            dev.log('SessionState: loaded from ${f.path}', name: 'TrackingSession');
            /// print: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            print('GW_ARES_SESSION_LOAD_FILE path=${f.path} len=$len');
            return m;
          } else {
            /// log: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            dev.log('SessionState: not found at ${f.path}', name: 'TrackingSession');
            /// print: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            print('GW_ARES_SESSION_LOAD_MISS path=${f.path}');
          }
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (e) {
          /// log: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          dev.log('SessionState: failed reading ${f.path} $e', name: 'TrackingSession');
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_SESSION_LOAD_FILE_FAIL path=${f.path} err=$e');
        }
      }
      try {
        /// getInstance: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final prefs = await SharedPreferences.getInstance();
        /// getString: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final raw = prefs.getString(_prefsKey);
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (raw != null) {
          /// log: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          dev.log('SessionState: loaded from SharedPreferences len=${raw.length}', name: 'TrackingSession');
          /// jsonDecode: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          final m = jsonDecode(raw) as Map<String, dynamic>;
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_SESSION_LOAD_PREFS len=${raw.length}');
          return m;
        } else {
          /// log: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          dev.log('SessionState: prefs key missing', name: 'TrackingSession');
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_SESSION_LOAD_PREFS_MISS');
        }
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) {
        /// log: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        dev.log('SessionState: prefs load failed $e', name: 'TrackingSession');
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_ARES_SESSION_LOAD_PREFS_FAIL err=$e');
      }
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      dev.log('SessionState: no session data found in any location', name: 'TrackingSession');
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_SESSION_LOAD_NONE');
      return null;
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      dev.log('SessionState: load exception $e', name: 'TrackingSession');
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_SESSION_LOAD_EXCEPTION err=$e');
      return null;
    }
  }

  /// clear: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static Future<void> clear() async {
    try {
      /// _candidateFiles: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final candidates = await _candidateFiles();
      /// for: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      for (final f in candidates) {
        try {
          /// if: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          if (await f.exists()) {
            /// delete: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            await f.delete();
            /// log: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            dev.log('SessionState: cleared ${f.path}', name: 'TrackingSession');
            /// print: [Brief description of what this function does]
            /// 
            /// **Parameters**: [Describe parameters if any]
            /// **Returns**: [Describe return value]
            print('GW_ARES_SESSION_CLEAR_FILE path=${f.path}');
          }
        /// catch: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        } catch (e) {
          /// log: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          dev.log('SessionState: failed clearing ${f.path} $e', name: 'TrackingSession');
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_SESSION_CLEAR_FILE_FAIL path=${f.path} err=$e');
        }
      }
      try {
        /// getInstance: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        final prefs = await SharedPreferences.getInstance();
        /// if: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        if (prefs.containsKey(_prefsKey)) {
          /// remove: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          await prefs.remove(_prefsKey);
          /// log: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          dev.log('SessionState: cleared SharedPreferences fallback', name: 'TrackingSession');
          /// print: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          print('GW_ARES_SESSION_CLEAR_PREFS');
        }
        /// setBool: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        await prefs.setBool(trackingActiveFlagKey, false);
      /// catch: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      } catch (e) {
        /// log: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        dev.log('SessionState: prefs clear failed $e', name: 'TrackingSession');
        /// print: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        print('GW_ARES_SESSION_CLEAR_PREFS_FAIL err=$e');
      }
    /// catch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    } catch (e) {
      /// log: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      dev.log('SessionState: clear exception $e', name: 'TrackingSession');
      /// print: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      print('GW_ARES_SESSION_CLEAR_EXCEPTION err=$e');
    }
  }
}
