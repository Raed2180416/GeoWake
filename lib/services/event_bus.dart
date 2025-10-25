import 'dart:async';

/// Base domain event (extend for specific payloads).
abstract class DomainEvent {
  DateTime get timestamp => DateTime.now();
  String get type; // machine-readable
}

class TeleportDetectedEvent extends DomainEvent {
  final double distanceMeters;
  TeleportDetectedEvent(this.distanceMeters);
  @override
  String get type => 'teleport_detected';
}

class BacktrackClampedEvent extends DomainEvent {
  final double regressionMeters;
  BacktrackClampedEvent(this.regressionMeters);
  @override
  String get type => 'backtrack_clamped';
}

class AlarmScheduledEvent extends DomainEvent {
  final int triggerEpochMs;
  AlarmScheduledEvent(this.triggerEpochMs);
  @override
  String get type => 'alarm_scheduled';
}

class AlarmFiredPhase1Event extends DomainEvent { @override String get type => 'alarm_fired_phase1'; }
class AlarmFiredPhase2Event extends DomainEvent { @override String get type => 'alarm_fired_phase2'; }
class AlarmRollbackEvent extends DomainEvent { @override String get type => 'alarm_rollback'; }
class AlarmShadowSuppressedEvent extends DomainEvent { @override String get type => 'alarm_shadow_suppressed'; }

class RouteSwitchedEvent extends DomainEvent {
  final String fromRouteId;
  final String toRouteId;
  RouteSwitchedEvent(this.fromRouteId, this.toRouteId);
  @override
  String get type => 'route_switched';
}

class RerouteDecisionEvent extends DomainEvent {
  final String cause; // e.g. sustained_deviation
  RerouteDecisionEvent(this.cause);
  @override
  String get type => 'reroute_decision';
}

class DeviationEnteredEvent extends DomainEvent { @override String get type => 'deviation_entered'; }
class DeviationClearedEvent extends DomainEvent { @override String get type => 'deviation_cleared'; }

class PowerModeChangedEvent extends DomainEvent {
  final String mode; // 'active' or 'idle'
  PowerModeChangedEvent(this.mode);
  @override
  String get type => 'power_mode_changed';
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final StreamController<DomainEvent> _controller = StreamController.broadcast();

  Stream<DomainEvent> get stream => _controller.stream;

  void emit(DomainEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  void dispose() { _controller.close(); }
}