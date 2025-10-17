part of 'package:geowake2/services/trackingservice.dart';

// ===================================================================
// BACKGROUND ISOLATE STATE
// ===================================================================
StreamSubscription<Position>? _positionSubscription;
DateTime? _lastGpsUpdate;
SensorFusionManager? _sensorFusionManager;
Timer? _gpsCheckTimer;
LatLng? _lastProcessedPosition;
double? _smoothedETA;
bool _fusionActive = false;
double? _lastSpeedMps;
final MovementClassifier _movementClassifier = MovementClassifier();
// EtaEngine modular abstraction (initially mirrors legacy smoothing semantics)
final EtaEngine _etaEngine = EtaEngine();
EtaResult? _lastEtaResult; // cached latest result for scheduling / diagnostics
// Support for injected test positions from foreground (demo path)
bool _useInjectedPositions = false;
StreamController<Position>? _injectedCtrl;
// Time-alarm gating state
DateTime? _startedAt;
LatLng? _startPosition;
double _distanceTravelledMeters = 0.0;
int _etaSamples = 0;
bool _timeAlarmEligible = false;
// Snapshot of effective minSinceStart used for eligibility (set on start)
Duration? _effectiveMinSinceStart;

// -------------------------------------------------------------------
// Adaptive continuous ETA / distance based alarm evaluation scheduling
// -------------------------------------------------------------------
DateTime? _lastAlarmEvalAt; // last actual _checkAndTriggerAlarm execution
Duration _lastDesiredEvalInterval = const Duration(seconds: 5);
DateTime? _burstModeStarted; // start time of current burst (if any)

// Tunable adaptive scheduling constants (non-final to allow test override)
Duration adaptiveFarInterval = const Duration(seconds: 60);      // ETA > 5x threshold
Duration adaptiveMidInterval = const Duration(seconds: 30);      // ETA 2–5x threshold
Duration adaptiveNearInterval = const Duration(seconds: 15);     // ETA 1–2x threshold
Duration adaptiveCloseInterval = const Duration(seconds: 5);     // ETA 0.5–1x threshold
Duration adaptiveVeryCloseInterval = const Duration(seconds: 2); // ETA 0.25–0.5x threshold
Duration adaptiveBurstInterval = const Duration(seconds: 1);     // Inside threshold (burst)
Duration adaptiveBurstMax = const Duration(seconds: 30);         // safety cap for burst mode
double adaptiveRapidEtaChangeFrac = 0.20; // 20% drop triggers immediate evaluation
double adaptiveReentryHysteresis = 1.10; // leave burst if ETA rises > 110% threshold

// Distance-based adaptive intervals (mirrors ETA scaling)
Duration adaptiveDistFarInterval = const Duration(seconds: 60);
Duration adaptiveDistMidInterval = const Duration(seconds: 30);
Duration adaptiveDistNearInterval = const Duration(seconds: 15);
Duration adaptiveDistCloseInterval = const Duration(seconds: 5);
Duration adaptiveDistVeryCloseInterval = const Duration(seconds: 2);
Duration adaptiveDistBurstInterval = const Duration(seconds: 1);
Duration adaptiveDistBurstMax = const Duration(seconds: 30);

bool get _inBurstMode => _burstModeStarted != null && DateTime.now().difference(_burstModeStarted!) <= adaptiveBurstMax;
void _exitBurstMode() { _burstModeStarted = null; }
void _enterBurstMode() { _burstModeStarted ??= DateTime.now(); }

// --- NEW STATE VARIABLES FOR ALARM LOGIC ---
LatLng? _origin;
LatLng? _destination;
String? _destinationName;
String? _alarmMode;
double? _alarmValue;
bool _destinationAlarmFired = false; // fire destination alarm only once
final Set<int> _firedEventIndexes = <int>{}; // indices into _routeEvents already fired
// Proximity stability gating
int _proximityConsecutivePasses = 0; // number of consecutive updates within threshold
DateTime? _proximityFirstPassAt; // when first entered threshold band
const int _proximityRequiredPasses = 3; // require N consecutive confirmations
const Duration _proximityMinDwell = Duration(seconds: 4); // require dwell inside threshold

// Event boundaries (transfers, mode changes) for multi-route safety
List<RouteEventBoundary> _routeEvents = const [];
List<double> _stepBoundsMeters = const [];
List<double> _stepStopsCumulative = const [];
int? _stopsPassesBelow; // hysteresis counter for remainingStops threshold
List<Map<String, dynamic>> _scenarioMilestones = const [];
Map<String, dynamic>? _scenarioRunConfig;
double? _scenarioTotalDurationSeconds;

// Route management and deviation/reroute state
final RouteRegistry _registry = RouteRegistry();
ActiveRouteManager? _activeManager;
DeviationMonitor? _devMonitor;
ReroutePolicy? _reroutePolicy;
OfflineCoordinator? _offlineCoordinator;
final _routeStateCtrl = StreamController<ActiveRouteState>.broadcast();
final _routeSwitchCtrl = StreamController<RouteSwitchEvent>.broadcast();
final _rerouteCtrl = StreamController<RerouteDecision>.broadcast();
IdlePowerScaler? _idleScaler; // lazy init

StreamSubscription<ActiveRouteState>? _mgrStateSub;
StreamSubscription<RouteSwitchEvent>? _mgrSwitchSub;
StreamSubscription<DeviationState>? _devSub;
StreamSubscription<RerouteDecision>? _rerouteSub;
bool _activeRouteInitialized = false;
bool _rerouteInFlight = false;
bool _transitMode = false;
ActiveRouteState? _lastActiveState;
LatLng? _firstTransitBoarding;
bool _preBoardingAlertFired = false;
String? _latestPowerMode; // background isolate power mode shadow

// Alarm evaluation re-entrancy guard (global in background isolate scope so listener can access).
bool _evalInProgress = false; // true while _checkAndTriggerAlarm runs
bool _pendingEval = false;    // single coalesced pending run flag

// =============================
// Dual‑run refactor components
// =============================
AlarmOrchestratorImpl? _orchestrator; // initialized lazily when tracking starts
StreamSubscription<AlarmEvent>? _orchSub; // test parity logging only
DateTime? _orchTriggeredAt; // parity timing capture
