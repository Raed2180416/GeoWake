import 'dart:developer' as dev;
import 'package:flutter_background_service/flutter_background_service.dart';

/// Simple structured logger facade to enable future redirection to metrics or files.
/// For now routes to dev.log; kept lightweight to avoid impacting production until wired.
class AppLogger {
  static AppLogger? _instance;
  static AppLogger get I => _instance ??= AppLogger();

  LogLevel minimumLevel = LogLevel.debug; // can be raised in release builds

  void log(String message, {String domain = 'core', LogLevel level = LogLevel.info, Map<String, Object?> context = const {}}) {
    if (level.index < minimumLevel.index) return;
    final ts = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final ctx = context.isEmpty ? '' : ' ' + _encodeContext(context);
    dev.log('[$ts][$levelStr][$domain] $message$ctx', name: 'AppLogger');
    // Best-effort bridge to foreground Diagnostics live log tail for interesting domains
    try {
      if (domain == 'alarm' || domain == 'session') {
        FlutterBackgroundService().invoke('logTail', {
          'level': levelStr,
          'domain': domain,
          'message': message,
          'context': context,
        });
      }
    } catch (e) {
      AppLogger.I.warn('Operation failed', domain: 'tracking', context: {'error': e.toString()});
    }
  }

  void debug(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.debug, context: context);
  void info(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.info, context: context);
  void warn(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.warn, context: context);
  void error(String m, {String domain='core', Map<String,Object?> context=const {}}) =>
      log(m, domain: domain, level: LogLevel.error, context: context);

  String _encodeContext(Map<String,Object?> ctx) => ctx.entries.map((e) => '${e.key}=${e.value}').join(' ');
}

enum LogLevel { debug, info, warn, error }
