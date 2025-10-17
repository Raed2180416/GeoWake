import 'dart:async';

/// Rollout stages for migrating from legacy alarm path to the new Orchestrator.
/// shadow: orchestrator executes evaluation logic but does NOT fire user-visible alarm (metrics only)
/// dual: both legacy and orchestrator can fire; orchestrator fires but duplicate suppression prevents double surfacing
/// primary: orchestrator is authoritative; legacy suppressed (can be re-enabled via hidden emergency flag)
enum OrchestratorRolloutStage { shadow, dual, primary }

typedef RolloutStageListener = void Function(OrchestratorRolloutStage stage);

class AlarmRolloutConfig {
  OrchestratorRolloutStage _stage = OrchestratorRolloutStage.shadow;
  bool _legacyEmergencyOverride = false; // hidden kill-switch to temporarily restore legacy if needed
  final _ctrl = StreamController<OrchestratorRolloutStage>.broadcast();

  static final AlarmRolloutConfig _instance = AlarmRolloutConfig._internal();
  factory AlarmRolloutConfig() => _instance;
  AlarmRolloutConfig._internal();

  OrchestratorRolloutStage get stage => _stage;
  bool get legacyEmergencyOverride => _legacyEmergencyOverride;
  Stream<OrchestratorRolloutStage> get changes => _ctrl.stream;

  void setStage(OrchestratorRolloutStage stage) {
    if (_stage == stage) return;
    _stage = stage;
    _ctrl.add(_stage);
  }

  /// Hidden override: when true, legacy path may still fire even in primary.
  void setLegacyEmergencyOverride(bool enabled) {
    _legacyEmergencyOverride = enabled;
  }
}

/// Duplicate suppression signature (type+routeId+bucket) TTL cache.
class AlarmDuplicateSuppressor {
  final Duration ttl;
  final Map<String, DateTime> _seen = {};

  AlarmDuplicateSuppressor({this.ttl = const Duration(minutes: 3)});

  /// Returns true if this signature is fresh (allowed) and records it; false if should suppress.
  bool allow(String type, String? routeId, DateTime at) {
    final bucketEpoch = at.millisecondsSinceEpoch ~/ 1000; // coarse second bucket; can refine later
    final key = '$type|${routeId ?? 'null'}|$bucketEpoch';
    _purgeExpired(at);
    final existing = _seen[key];
    if (existing != null) {
      return false; // duplicate within TTL
    }
    _seen[key] = at;
    return true;
  }

  void _purgeExpired(DateTime now) {
    final cutoff = now.subtract(ttl);
    _seen.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  void clear() => _seen.clear();
}
