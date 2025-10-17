import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../trackingservice.dart';
import '../transfer_utils.dart';
import 'route_simulator.dart';

enum MetroAlarmMode { distance, stops, time }

extension MetroAlarmModeValue on MetroAlarmMode {
  String get value => switch (this) {
        MetroAlarmMode.distance => 'distance',
        MetroAlarmMode.stops => 'stops',
        MetroAlarmMode.time => 'time',
      };
}

class MetroScenarioRunOptions {
  const MetroScenarioRunOptions({
    required this.mode,
    required this.distanceMeters,
    required this.stopsThreshold,
    required this.timeMinutes,
    required this.eventTriggerWindowMeters,
    required this.speedMultiplier,
  });

  factory MetroScenarioRunOptions.defaults(MetroRouteScenarioConfig config) {
    return MetroScenarioRunOptions(
      mode: MetroAlarmMode.distance,
      distanceMeters: config.defaultDistanceMeters,
      stopsThreshold: config.defaultStopsThreshold,
      timeMinutes: config.defaultTimeMinutes,
      eventTriggerWindowMeters: config.defaultEventWindowMeters,
      speedMultiplier: config.defaultSpeedMultiplier,
    );
  }

  final MetroAlarmMode mode;
  final double distanceMeters;
  final double stopsThreshold;
  final double timeMinutes;
  final double eventTriggerWindowMeters;
  final double speedMultiplier;

  MetroScenarioRunOptions copyWith({
    MetroAlarmMode? mode,
    double? distanceMeters,
    double? stopsThreshold,
    double? timeMinutes,
    double? eventTriggerWindowMeters,
    double? speedMultiplier,
  }) {
    return MetroScenarioRunOptions(
      mode: mode ?? this.mode,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      stopsThreshold: stopsThreshold ?? this.stopsThreshold,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      eventTriggerWindowMeters: eventTriggerWindowMeters ?? this.eventTriggerWindowMeters,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
    );
  }
}

class MetroScenarioMilestone {
  const MetroScenarioMilestone({
    required this.id,
    required this.label,
    required this.type,
    required this.metersFromStart,
    required this.cumulativeStops,
    required this.etaSeconds,
  });

  final String id;
  final String label;
  final String type;
  final double metersFromStart;
  final double cumulativeStops;
  final double etaSeconds;
}

class MetroScenarioSnapshot {
  const MetroScenarioSnapshot({
    required this.totalMeters,
    required this.totalStops,
    required this.totalSeconds,
    required this.milestones,
    required this.events,
    required this.run,
  });

  final double totalMeters;
  final double totalStops;
  final double totalSeconds;
  final List<MetroScenarioMilestone> milestones;
  final List<RouteEventBoundary> events;
  final MetroScenarioRunOptions run;
}

class MetroRouteScenarioConfig {
  final Duration tickInterval;
  final double baseSpeedMps;
  final bool enableFullOrchestrator;
  final double defaultDistanceMeters;
  final double defaultStopsThreshold;
  final double defaultTimeMinutes;
  final double defaultEventWindowMeters;
  final double defaultSpeedMultiplier;

  const MetroRouteScenarioConfig({
    this.tickInterval = const Duration(milliseconds: 900),
    this.baseSpeedMps = 14.0,
    this.enableFullOrchestrator = true,
    this.defaultDistanceMeters = 120.0,
    this.defaultStopsThreshold = 3.0,
    this.defaultTimeMinutes = 5.0,
    this.defaultEventWindowMeters = 80.0,
    this.defaultSpeedMultiplier = 12.0,
  });
}

class MetroRouteScenarioRunner {
  MetroRouteScenarioRunner({
    this.config = const MetroRouteScenarioConfig(),
    this.destinationName = 'Sumadhura Shikharam',
  });

  final MetroRouteScenarioConfig config;
  final String destinationName;

  RouteSimulationController? _controller;
  bool _appliedOverrides = false;
  MetroScenarioSnapshot? _lastSnapshot;
  MetroScenarioRunOptions? _lastRun;

  MetroScenarioSnapshot? get lastSnapshot => _lastSnapshot;
  MetroScenarioRunOptions? get lastRunOptions => _lastRun;

  static const List<LatLng> _polyline = <LatLng>[
    LatLng(13.05236, 77.51905), // Rajasthani Family Restaurant (start)
    LatLng(13.05285, 77.51532), // Nagasandra Metro station
    LatLng(13.04710, 77.53180), // Jalahalli cross
    LatLng(13.04520, 77.54860), // Yeshwanthpur vicinity
    LatLng(13.03360, 77.55520), // Rajajinagar
    LatLng(13.00890, 77.56990), // Mantri Square / Sampige Road
    LatLng(12.97700, 77.57180), // Majestic interchange
    LatLng(12.97320, 77.59960), // Vidhana Soudha
    LatLng(12.97110, 77.62000), // Trinity
    LatLng(12.97870, 77.64140), // Indiranagar
    LatLng(12.99340, 77.69460), // KR Puram
    LatLng(12.99910, 77.72870), // Hope Farm Junction
    LatLng(12.99780, 77.75130), // Whitefield metro
    LatLng(12.99830, 77.75820), // Kadugodi depot exit
    LatLng(13.00240, 77.76660), // Seegehalli main road
    LatLng(13.00490, 77.77140), // Sumadhura Shikharam (destination)
  ];

  static const List<int> _segmentStopAllocation = <int>[
    0, // drive-in
    3,
    3,
    2,
    2,
    2,
    3,
    3,
    3,
    3,
    4,
    3,
    0,
    0,
    0,
  ];

  static const List<double> _segmentSpeedMps = <double>[
    11.0, // local drive
    20.0,
    20.0,
    20.0,
    20.0,
    20.0,
    23.0,
    23.0,
    23.0,
    23.0,
    23.0,
    23.0,
    8.0, // last-mile surface
    8.0,
    6.0,
  ];

  static const List<_MilestoneDefinition> _milestoneDefinitions = <_MilestoneDefinition>[
    _MilestoneDefinition(
      pointIndex: 1,
      id: 'board_nagasandra',
      type: 'mode_change',
      label: 'Board metro at Nagasandra',
    ),
    _MilestoneDefinition(
      pointIndex: 6,
      id: 'transfer_majestic',
      type: 'transfer',
      label: 'Change line at Majestic interchange',
    ),
    _MilestoneDefinition(
      pointIndex: 12,
      id: 'exit_whitefield',
      type: 'transfer',
      label: 'Prepare to exit at Whitefield metro',
    ),
    _MilestoneDefinition(
      pointIndex: 15,
      id: 'destination_arrival',
      type: 'destination',
      label: 'Arrive at Sumadhura Shikharam',
    ),
  ];

  static final Map<int, _MilestoneDefinition> _milestonesByIndex = {
    for (final m in _milestoneDefinitions) m.pointIndex: m,
  };

  Future<MetroScenarioSnapshot> start({MetroScenarioRunOptions? options}) async {
    if (_controller != null) {
      await stop();
    }

    final run = options ?? MetroScenarioRunOptions.defaults(config);
    final controller = RouteSimulationController(
      polyline: _polyline,
      baseSpeedMps: config.baseSpeedMps,
      tickInterval: config.tickInterval,
    );
    _controller = controller;

    final metrics = _computeMetrics();

    if (config.enableFullOrchestrator) {
      TrackingService.useOrchestratorForDestinationAlarm = true;
    }

    final alarmMode = run.mode.value;
    final alarmValue = switch (run.mode) {
      MetroAlarmMode.distance => run.distanceMeters,
      MetroAlarmMode.stops => run.stopsThreshold,
      MetroAlarmMode.time => run.timeMinutes,
    };

    await controller.startTrackingWithSimulation(
      destinationName: destinationName,
      alarmMode: alarmMode,
      alarmValue: alarmValue,
    );

    await _applyScenarioOverrides(
      totalLengthMeters: metrics.totalLengthMeters,
      routeEvents: metrics.events,
      totalStops: metrics.totalStops,
      eventWindowMeters: run.eventTriggerWindowMeters,
      stepBounds: metrics.stepBounds,
      stepStops: metrics.stepStops,
      milestones: metrics.milestones
          .map((m) => {
                'id': m.id,
                'label': m.label,
                'type': m.type,
                'metersFromStart': m.metersFromStart,
                'cumulativeStops': m.cumulativeStops,
                'etaSeconds': m.etaSeconds,
              })
          .toList(growable: false),
      totalDurationSeconds: metrics.totalDurationSeconds,
      runConfig: {
        'mode': run.mode.value,
        'distanceMeters': run.distanceMeters,
        'stopsThreshold': run.stopsThreshold,
        'timeMinutes': run.timeMinutes,
        'eventTriggerWindowMeters': run.eventTriggerWindowMeters,
        'speedMultiplier': run.speedMultiplier,
      },
    );

    if (run.speedMultiplier != 1.0) {
      controller.setSpeedMultiplier(run.speedMultiplier);
    }

    controller.start();

    final snapshot = MetroScenarioSnapshot(
      totalMeters: metrics.totalLengthMeters,
      totalStops: metrics.totalStops,
      totalSeconds: metrics.totalDurationSeconds,
      milestones: metrics.milestones,
      events: metrics.events,
      run: run,
    );
    _lastSnapshot = snapshot;
    _lastRun = run;
    return snapshot;
  }

  Future<void> stop() async {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
    _appliedOverrides = false;
  }

  bool get isRunning => _controller != null;

  void setSpeedMultiplier(double multiplier) {
    _controller?.setSpeedMultiplier(multiplier);
  }

  Future<void> _applyScenarioOverrides({
    required double totalLengthMeters,
    required List<RouteEventBoundary> routeEvents,
    required double totalStops,
    required double eventWindowMeters,
    required List<double> stepBounds,
    required List<double> stepStops,
    List<Map<String, dynamic>>? milestones,
    double? totalDurationSeconds,
    Map<String, dynamic>? runConfig,
  }) async {
    if (_appliedOverrides) return;
    await TrackingService().applyScenarioOverrides(
      totalRouteMeters: totalLengthMeters,
      totalStops: totalStops,
      events: routeEvents,
      eventTriggerWindowMeters: eventWindowMeters,
      stepBounds: stepBounds,
      stepStops: stepStops,
      milestones: milestones,
      totalDurationSeconds: totalDurationSeconds,
      runConfig: runConfig,
    );
    _appliedOverrides = true;
  }

  _ScenarioMetrics _computeMetrics() {
    double cumMeters = 0.0;
    double cumStops = 0.0;
    double cumSeconds = 0.0;
    final events = <RouteEventBoundary>[];
    final bounds = <double>[0.0];
    final stops = <double>[0.0];
    final milestones = <MetroScenarioMilestone>[];

    for (int i = 0; i < _polyline.length - 1; i++) {
      final from = _polyline[i];
      final to = _polyline[i + 1];
      final segMeters = Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      final segSpeed = (i < _segmentSpeedMps.length && _segmentSpeedMps[i] > 0)
          ? _segmentSpeedMps[i]
          : config.baseSpeedMps;
      final segSeconds = segSpeed <= 0 ? 0 : segMeters / segSpeed;

      cumMeters += segMeters;
      cumStops += (i < _segmentStopAllocation.length) ? _segmentStopAllocation[i].toDouble() : 0.0;
      cumSeconds += segSeconds;

      final milestoneDef = _milestonesByIndex[i + 1];
      if (milestoneDef != null) {
        events.add(RouteEventBoundary(
          meters: cumMeters,
          type: milestoneDef.type,
          label: milestoneDef.label,
        ));
        milestones.add(MetroScenarioMilestone(
          id: milestoneDef.id,
          label: milestoneDef.label,
          type: milestoneDef.type,
          metersFromStart: cumMeters,
          cumulativeStops: cumStops,
          etaSeconds: cumSeconds,
        ));
      }

      bounds.add(cumMeters);
      stops.add(cumStops);
    }

    final totalStops = stops.isNotEmpty ? stops.last : 0.0;
    final totalDurationSeconds = cumSeconds;

    // Ensure destination milestone captured even if not in definitions
    final hasDestination = milestones.any((m) => m.id == 'destination_arrival');
    if (!hasDestination) {
      milestones.add(MetroScenarioMilestone(
        id: 'destination_arrival',
        label: 'Arrive at destination',
        type: 'destination',
        metersFromStart: cumMeters,
        cumulativeStops: totalStops,
        etaSeconds: totalDurationSeconds,
      ));
    }

    return _ScenarioMetrics(
      totalLengthMeters: cumMeters,
      totalStops: totalStops,
      totalDurationSeconds: totalDurationSeconds,
      events: events,
      stepBounds: bounds,
      stepStops: stops,
      milestones: milestones,
    );
  }
}

class _ScenarioMetrics {
  const _ScenarioMetrics({
    required this.totalLengthMeters,
    required this.totalStops,
    required this.totalDurationSeconds,
    required this.events,
    required this.stepBounds,
    required this.stepStops,
    required this.milestones,
  });

  final double totalLengthMeters;
  final double totalStops;
  final double totalDurationSeconds;
  final List<RouteEventBoundary> events;
  final List<double> stepBounds;
  final List<double> stepStops;
  final List<MetroScenarioMilestone> milestones;
}

class _MilestoneDefinition {
  const _MilestoneDefinition({
    required this.pointIndex,
    required this.id,
    required this.type,
    required this.label,
  });

  final int pointIndex;
  final String id;
  final String type;
  final String label;
}
