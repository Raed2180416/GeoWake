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
  static const _filename = 'tracking_session.json';
  static const _prefsKey = 'tracking_session_json_v1';
  // New lightweight boolean flag to allow ultra-fast auto-resume checks
  static const trackingActiveFlagKey = 'tracking_active_v1';

  static Future<List<File>> _candidateFiles() async {
    final files = <File>[];
    try {
      final appSupport = await getApplicationSupportDirectory();
      files.add(File('${appSupport.path}/$_filename'));
    } catch (_) {}
    try {
      final docs = await getApplicationDocumentsDirectory();
      files.add(File('${docs.path}/$_filename'));
    } catch (_) {}
    // (Optional) external storage dir (Android only) not added to avoid extra permission complexity.
    return files;
  }

  static Future<void> save(Map<String, dynamic> data) async {
    try {
      final jsonStr = jsonEncode(data);
      final len = jsonStr.length;
      dev.log('SessionState: save start (len=$len)', name: 'TrackingSession');
      // Stdout prints (prefixed) so they appear even if dev.log is filtered
      // Unique token: GW_ARES (GeoWake Auto RESume)
      // DO NOT REMOVE: Used for field diagnostics when dev.log signals missing.
      // Using print instead of debugPrint to avoid throttling and ensure logcat visibility.
      print('GW_ARES_SESSION_SAVE len=$len');
      final candidates = await _candidateFiles();
      for (final f in candidates) {
        try {
          await f.writeAsString(jsonStr, flush: true);
          final exists = await f.exists();
          final sz = exists ? (await f.length()) : -1;
            dev.log('SessionState: saved to ${f.path} size=$sz', name: 'TrackingSession');
            print('GW_ARES_SESSION_FILE_WRITE path=${f.path} size=$sz');
        } catch (e) {
          dev.log('SessionState: write failed to ${f.path} $e', name: 'TrackingSession');
          print('GW_ARES_SESSION_FILE_WRITE_FAIL path=${f.path} err=$e');
        }
      }
      // Always persist to SharedPreferences as well for resilience.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonStr);
        await prefs.setBool(trackingActiveFlagKey, true);
        dev.log('SessionState: saved to SharedPreferences (redundant)', name: 'TrackingSession');
        print('GW_ARES_SESSION_PREFS_WRITE ok jsonLen=$len');
      } catch (e) {
        dev.log('SessionState: prefs write failed $e', name: 'TrackingSession');
        print('GW_ARES_SESSION_PREFS_WRITE_FAIL err=$e');
      }
    } catch (e) {
      dev.log('SessionState: save exception $e', name: 'TrackingSession');
      print('GW_ARES_SESSION_SAVE_EXCEPTION err=$e');
    }
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      print('GW_ARES_SESSION_LOAD_START');
      final candidates = await _candidateFiles();
      for (final f in candidates) {
        try {
          if (await f.exists()) {
            final len = await f.length();
            final raw = await f.readAsString();
            dev.log('SessionState: candidate ${f.path} exists len=$len', name: 'TrackingSession');
            final m = jsonDecode(raw) as Map<String, dynamic>;
            dev.log('SessionState: loaded from ${f.path}', name: 'TrackingSession');
            print('GW_ARES_SESSION_LOAD_FILE path=${f.path} len=$len');
            return m;
          } else {
            dev.log('SessionState: not found at ${f.path}', name: 'TrackingSession');
            print('GW_ARES_SESSION_LOAD_MISS path=${f.path}');
          }
        } catch (e) {
          dev.log('SessionState: failed reading ${f.path} $e', name: 'TrackingSession');
          print('GW_ARES_SESSION_LOAD_FILE_FAIL path=${f.path} err=$e');
        }
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_prefsKey);
        if (raw != null) {
          dev.log('SessionState: loaded from SharedPreferences len=${raw.length}', name: 'TrackingSession');
          final m = jsonDecode(raw) as Map<String, dynamic>;
          print('GW_ARES_SESSION_LOAD_PREFS len=${raw.length}');
          return m;
        } else {
          dev.log('SessionState: prefs key missing', name: 'TrackingSession');
          print('GW_ARES_SESSION_LOAD_PREFS_MISS');
        }
      } catch (e) {
        dev.log('SessionState: prefs load failed $e', name: 'TrackingSession');
        print('GW_ARES_SESSION_LOAD_PREFS_FAIL err=$e');
      }
      dev.log('SessionState: no session data found in any location', name: 'TrackingSession');
      print('GW_ARES_SESSION_LOAD_NONE');
      return null;
    } catch (e) {
      dev.log('SessionState: load exception $e', name: 'TrackingSession');
      print('GW_ARES_SESSION_LOAD_EXCEPTION err=$e');
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final candidates = await _candidateFiles();
      for (final f in candidates) {
        try {
          if (await f.exists()) {
            await f.delete();
            dev.log('SessionState: cleared ${f.path}', name: 'TrackingSession');
            print('GW_ARES_SESSION_CLEAR_FILE path=${f.path}');
          }
        } catch (e) {
          dev.log('SessionState: failed clearing ${f.path} $e', name: 'TrackingSession');
          print('GW_ARES_SESSION_CLEAR_FILE_FAIL path=${f.path} err=$e');
        }
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(_prefsKey)) {
          await prefs.remove(_prefsKey);
          dev.log('SessionState: cleared SharedPreferences fallback', name: 'TrackingSession');
          print('GW_ARES_SESSION_CLEAR_PREFS');
        }
        await prefs.setBool(trackingActiveFlagKey, false);
      } catch (e) {
        dev.log('SessionState: prefs clear failed $e', name: 'TrackingSession');
        print('GW_ARES_SESSION_CLEAR_PREFS_FAIL err=$e');
      }
    } catch (e) {
      dev.log('SessionState: clear exception $e', name: 'TrackingSession');
      print('GW_ARES_SESSION_CLEAR_EXCEPTION err=$e');
    }
  }
}
