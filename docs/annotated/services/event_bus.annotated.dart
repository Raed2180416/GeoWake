import 'dart:async';

/// Base domain event (extend for specific payloads).
/// 
/// **Purpose**: Represents significant occurrences in the application domain
/// that other parts of the system may need to react to. Using an event bus
/// decouples producers from consumers.
///
/// **Pattern**: Domain Event / Observer pattern
/// - Events are immutable snapshots of what happened
/// - Events flow through EventBus to interested subscribers
/// - Subscribers react without direct coupling to event source
abstract class DomainEvent {
  /// When the event occurred (can be overridden in subclasses for testing)
  DateTime get timestamp => DateTime.now();
  
  /// Machine-readable event type identifier
  /// Used for logging, metrics, and filtering in subscribers
  String get type;
}

/// Fired when a large GPS jump is detected (possible teleport or GPS glitch)
/// 
/// **When**: Position changes by >500m between samples
/// **Usage**: Log for debugging, potentially reset tracking state
class TeleportDetectedEvent extends DomainEvent {
  /// Distance of the jump in meters
  final double distanceMeters;
  TeleportDetectedEvent(this.distanceMeters);
  @override
  String get type => 'teleport_detected';
}

/// Fired when progress regresses (user appears to move backward on route)
/// 
/// **When**: Calculated progress decreases instead of increasing
/// **Usage**: Clamp progress to prevent negative movement, log anomaly
class BacktrackClampedEvent extends DomainEvent {
  /// How far backward the regression was (in meters)
  final double regressionMeters;
  BacktrackClampedEvent(this.regressionMeters);
  @override
  String get type => 'backtrack_clamped';
}

/// Fired when a fallback OS alarm is scheduled
/// 
/// **When**: App schedules alarm with OS to ensure it fires even if app dies
/// **Usage**: Log for debugging, update UI to show alarm is armed
class AlarmScheduledEvent extends DomainEvent {
  /// When the alarm will fire (UTC epoch milliseconds)
  final int triggerEpochMs;
  AlarmScheduledEvent(this.triggerEpochMs);
  @override
  String get type => 'alarm_scheduled';
}

/// Phase 1 of alarm firing: notification shown
/// 
/// **When**: High-priority notification successfully displayed
/// **Next**: Phase 2 will play audio/vibration
class AlarmFiredPhase1Event extends DomainEvent { 
  @override String get type => 'alarm_fired_phase1'; 
}

/// Phase 2 of alarm firing: audio/vibration started
/// 
/// **When**: Alarm sound and vibration successfully activated
/// **Note**: Alarm is now fully active
class AlarmFiredPhase2Event extends DomainEvent { 
  @override String get type => 'alarm_fired_phase2'; 
}

/// Alarm was rolled back due to error
/// 
/// **When**: Alarm partially fired but had to abort (e.g., audio failed)
/// **Usage**: Log error, potentially retry or show error to user
class AlarmRollbackEvent extends DomainEvent { 
  @override String get type => 'alarm_rollback'; 
}

/// Alarm was suppressed due to shadow mode
/// 
/// **When**: Alarm would have fired but orchestrator is in shadow/testing mode
/// **Usage**: Metrics collection without affecting user
class AlarmShadowSuppressedEvent extends DomainEvent { 
  @override String get type => 'alarm_shadow_suppressed'; 
}

/// Active route switched to a different route
/// 
/// **When**: App determines a different route is better and switches to it
/// **Usage**: Update UI, clear old route state, start tracking new route
class RouteSwitchedEvent extends DomainEvent {
  /// ID of the route we switched from
  final String fromRouteId;
  
  /// ID of the route we switched to
  final String toRouteId;
  
  RouteSwitchedEvent(this.fromRouteId, this.toRouteId);
  @override
  String get type => 'route_switched';
}

/// Decision made to request route recalculation
/// 
/// **When**: Sustained deviation or user went off-route
/// **Usage**: Trigger API call to get new route, log for debugging
class RerouteDecisionEvent extends DomainEvent {
  /// Why reroute was triggered (e.g., "sustained_deviation", "large_deviation")
  final String cause;
  RerouteDecisionEvent(this.cause);
  @override
  String get type => 'reroute_decision';
}

/// User has gone off-route (beyond deviation threshold)
/// 
/// **When**: Lateral distance from route exceeds threshold
/// **Usage**: Show UI indicator, start reroute timer
class DeviationEnteredEvent extends DomainEvent { 
  @override String get type => 'deviation_entered'; 
}

/// User is back on route (within deviation threshold)
/// 
/// **When**: Lateral distance from route is acceptable again
/// **Usage**: Clear UI indicator, cancel reroute timer
class DeviationClearedEvent extends DomainEvent { 
  @override String get type => 'deviation_cleared'; 
}

/// Power mode changed (e.g., active -> idle or vice versa)
/// 
/// **When**: Battery level or user activity triggers mode change
/// **Usage**: Adjust GPS update frequency, throttle background work
class PowerModeChangedEvent extends DomainEvent {
  /// New mode: 'active' (normal tracking) or 'idle' (power-saving)
  final String mode;
  PowerModeChangedEvent(this.mode);
  @override
  String get type => 'power_mode_changed';
}

/// Singleton event bus for publishing and subscribing to domain events
/// 
/// **Purpose**: Central hub for app-wide events. Decouples components by
/// allowing them to communicate without direct references.
///
/// **Usage - Publishing**:
/// ```dart
/// EventBus().emit(AlarmFiredPhase1Event());
/// ```
///
/// **Usage - Subscribing**:
/// ```dart
/// final subscription = EventBus().stream.listen((event) {
///   if (event is AlarmFiredPhase1Event) {
///     // React to alarm
///   }
/// });
/// // Don't forget to cancel subscription when done
/// subscription.cancel();
/// ```
///
/// **Thread safety**: Stream is broadcast, so multiple listeners are supported.
/// Events are delivered synchronously on the same isolate.
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  /// Internal stream controller for event distribution
  final StreamController<DomainEvent> _controller = StreamController.broadcast();

  /// Stream of all domain events
  /// Subscribe to this to receive events
  Stream<DomainEvent> get stream => _controller.stream;

  /// Publish an event to all subscribers
  /// 
  /// **Note**: If controller is closed, event is silently dropped
  /// (prevents errors during app shutdown)
  void emit(DomainEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  /// Close the event bus (call during app shutdown)
  /// After calling this, no more events can be emitted
  void dispose() { _controller.close(); }
}
