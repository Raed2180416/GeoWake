/// alarm_rollout.dart: Source file from lib/lib/services/alarm_rollout.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'dart:async';

/// Rollout stages for migrating from legacy alarm path to the new Orchestrator.
/// shadow: orchestrator executes evaluation logic but does NOT fire user-visible alarm (metrics only)
/// dual: both legacy and orchestrator can fire; orchestrator fires but duplicate suppression prevents double surfacing
/// primary: orchestrator is authoritative; legacy suppressed (can be re-enabled via hidden emergency flag)
enum OrchestratorRolloutStage { shadow, dual, primary }

typedef RolloutStageListener = void Function(OrchestratorRolloutStage stage);

/// AlarmRolloutConfig: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class AlarmRolloutConfig {
  OrchestratorRolloutStage _stage = OrchestratorRolloutStage.shadow;
  bool _legacyEmergencyOverride = false; // hidden kill-switch to temporarily restore legacy if needed
  /// broadcast: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  final _ctrl = StreamController<OrchestratorRolloutStage>.broadcast();

  /// _internal: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  static final AlarmRolloutConfig _instance = AlarmRolloutConfig._internal();
  factory AlarmRolloutConfig() => _instance;
  /// _internal: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  AlarmRolloutConfig._internal();

  OrchestratorRolloutStage get stage => _stage;
  bool get legacyEmergencyOverride => _legacyEmergencyOverride;
  Stream<OrchestratorRolloutStage> get changes => _ctrl.stream;

  /// setStage: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setStage(OrchestratorRolloutStage stage) {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_stage == stage) return;
    _stage = stage;
    /// add: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _ctrl.add(_stage);
  }

  /// Hidden override: when true, legacy path may still fire even in primary.
  void setLegacyEmergencyOverride(bool enabled) {
    _legacyEmergencyOverride = enabled;
  }
}

/// Duplicate suppression signature (type+routeId+bucket) TTL cache.
class AlarmDuplicateSuppressor {
  /// [Brief description of this field]
  final Duration ttl;
  /// [Brief description of this field]
  final Map<String, DateTime> _seen = {};

  AlarmDuplicateSuppressor({this.ttl = const Duration(minutes: 3)});

  /// Returns true if this signature is fresh (allowed) and records it; false if should suppress.
  bool allow(String type, String? routeId, DateTime at) {
    /// [Brief description of this field]
    final bucketEpoch = at.millisecondsSinceEpoch ~/ 1000; // coarse second bucket; can refine later
    /// [Brief description of this field]
    final key = '$type|${routeId ?? 'null'}|$bucketEpoch';
    /// _purgeExpired: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _purgeExpired(at);
    /// [Brief description of this field]
    final existing = _seen[key];
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (existing != null) {
      return false; // duplicate within TTL
    }
    _seen[key] = at;
    return true;
  }

  /// _purgeExpired: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void _purgeExpired(DateTime now) {
    /// subtract: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final cutoff = now.subtract(ttl);
    /// removeWhere: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _seen.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  /// clear: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void clear() => _seen.clear();
}
