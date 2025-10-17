import 'interfaces.dart';
import 'location_types.dart';
import '../../logging/app_logger.dart';

/// Temporary facade placeholder. Will gradually absorb logic from trackingservice.
class TrackingSessionFacadeImpl implements TrackingSessionFacade {
  final LocationPipeline locationPipeline;
  final PowerModeController powerController;
  final DeviationEngine deviationEngine;
  final AlarmOrchestrator alarmOrchestrator;
  final SessionStateStore stateStore;
  final NotificationGateway notifications;

  TrackingSessionFacadeImpl({
    required this.locationPipeline,
    required this.powerController,
    required this.deviationEngine,
    required this.alarmOrchestrator,
    required this.stateStore,
    required this.notifications,
  });

  // NOTE: alarmOrchestrator should be an instance of AlarmOrchestratorImpl (phase1)
  // In later phases we will dual-run with legacy logic for parity validation.

  Stream<AlarmEvent> get alarmEvents$ => alarmOrchestrator.events$;
  Stream<PowerMode> get powerMode$ => powerController.mode$;

  bool _running = false;
  late final Stream<LocationSample> _sampleStream;

  @override
  Future<void> start({required DestinationSpec destination, required AlarmConfig alarmConfig}) async {
    if (_running) return;
    _running = true;
    alarmOrchestrator.configure(alarmConfig);
    alarmOrchestrator.registerDestination(destination);
    await locationPipeline.start(const LocationPipelineConfig());
    _sampleStream = locationPipeline.samples$;
    _sampleStream.listen((sample) {
      try {
        powerController.ingest(sample);
        // For now we avoid snapping logic until migrated; call placeholder snap
        final snapped = deviationEngine.snap(sample);
        alarmOrchestrator.update(sample: sample, snapped: snapped);
      } catch (e) {
        AppLogger.I.warn('Facade sample processing error', domain: 'facade', context: {'error': e.toString()});
      }
    });
    AppLogger.I.info('Tracking session started (facade stub)', domain: 'facade');
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await locationPipeline.stop();
    AppLogger.I.info('Tracking session stopped (facade stub)', domain: 'facade');
  }
}
