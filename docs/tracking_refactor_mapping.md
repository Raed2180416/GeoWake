## Tracking Service Refactor Mapping (Initial Draft)

This document maps existing responsibilities inside `trackingservice.dart` to new modular components.

| Responsibility | Current Location | Target Module |
|----------------|------------------|---------------|
| GPS subscription & policy selection | trackingservice.startLocationStream | LocationPipeline |
| Sensor fusion fallback & dropout handling | trackingservice timers / fusion manager | LocationPipeline |
| Idle power scaling (IdlePowerScaler) | trackingservice (inline) | PowerModeController + LocationPipeline cadence adjustments |
| Snapping to route | trackingservice / ActiveRouteManager | DeviationEngine |
| Deviation detection & hysteresis | trackingservice / deviation monitor | DeviationEngine |
| Route switching sustain/blackout | ActiveRouteManager & trackingservice | RouteManager + DeviationEngine integration |
| Alarm gating (distance/time/stops) | trackingservice (interwoven) | AlarmOrchestrator |
| Alarm fallback scheduling | trackingservice + platform scheduler | AlarmOrchestrator (uses AlarmScheduler) |
| Alarm rollback on failure | trackingservice | AlarmOrchestrator |
| Notifications (progress + alarm) | trackingservice + NotificationService | NotificationGateway |
| Power mode events | trackingservice | PowerModeController |
| Event emission (DomainEvent) | scattered | Emitted at module boundaries via facade |
| Session persistence (pending alarm etc.) | trackingservice / prefs | SessionStateStore |
| Token refresh & auth | ApiClient | (unchanged) |
| Test hooks (streams & thresholds) | Static fields on TrackingService | Constructor DI (LocationPipelineConfig, AlarmConfig, factories) |
| Logging & debug prints | dev.log / print scattered | AppLogger centralized |

### Next Steps
1. Implement concrete Logger usage & remove debug prints.
2. Provide concrete AlarmOrchestrator (dual-run with legacy for parity validation).
3. Introduce real LocationPipeline re-subscribing on cadence change events from PowerModeController.
