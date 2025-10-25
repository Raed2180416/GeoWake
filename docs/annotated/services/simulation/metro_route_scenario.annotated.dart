/// metro_route_scenario.dart: Source file from lib/lib/services/simulation/metro_route_scenario.dart
/// 
/// This annotated version provides detailed documentation for all classes, methods, and fields.

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../trackingservice.dart';
import '../transfer_utils.dart';
import 'route_simulator.dart';

enum MetroAlarmMode { distance, stops, time }

extension MetroAlarmModeValue on MetroAlarmMode {
  /// switch: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  String get value => switch (this) {
        MetroAlarmMode.distance => 'distance',
        MetroAlarmMode.stops => 'stops',
        MetroAlarmMode.time => 'time',
      };
}

/// MetroScenarioRunOptions: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class MetroScenarioRunOptions {
  const MetroScenarioRunOptions({
    required this.mode,
    required this.distanceMeters,
    required this.stopsThreshold,
    required this.timeMinutes,
    required this.eventTriggerWindowMeters,
    required this.speedMultiplier,
  });

  /// defaults: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
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

  /// [Brief description of this field]
  final MetroAlarmMode mode;
  /// [Brief description of this field]
  final double distanceMeters;
  /// [Brief description of this field]
  final double stopsThreshold;
  /// [Brief description of this field]
  final double timeMinutes;
  /// [Brief description of this field]
  final double eventTriggerWindowMeters;
  /// [Brief description of this field]
  final double speedMultiplier;

  /// copyWith: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
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

/// MetroScenarioMilestone: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class MetroScenarioMilestone {
  const MetroScenarioMilestone({
    required this.id,
    required this.label,
    required this.type,
    required this.metersFromStart,
    required this.cumulativeStops,
    required this.etaSeconds,
  });

  /// [Brief description of this field]
  final String id;
  /// [Brief description of this field]
  final String label;
  /// [Brief description of this field]
  final String type;
  /// [Brief description of this field]
  final double metersFromStart;
  /// [Brief description of this field]
  final double cumulativeStops;
  /// [Brief description of this field]
  final double etaSeconds;
}

/// MetroScenarioSnapshot: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class MetroScenarioSnapshot {
  const MetroScenarioSnapshot({
    required this.totalMeters,
    required this.totalStops,
    required this.totalSeconds,
    required this.milestones,
    required this.events,
    required this.run,
  });

  /// [Brief description of this field]
  final double totalMeters;
  /// [Brief description of this field]
  final double totalStops;
  /// [Brief description of this field]
  final double totalSeconds;
  /// [Brief description of this field]
  final List<MetroScenarioMilestone> milestones;
  /// [Brief description of this field]
  final List<RouteEventBoundary> events;
  /// [Brief description of this field]
  final MetroScenarioRunOptions run;
}

/// MetroRouteScenarioConfig: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class MetroRouteScenarioConfig {
  /// [Brief description of this field]
  final Duration tickInterval;
  /// [Brief description of this field]
  final double baseSpeedMps;
  /// [Brief description of this field]
  final bool enableFullOrchestrator;
  /// [Brief description of this field]
  final double defaultDistanceMeters;
  /// [Brief description of this field]
  final double defaultStopsThreshold;
  /// [Brief description of this field]
  final double defaultTimeMinutes;
  /// [Brief description of this field]
  final double defaultEventWindowMeters;
  /// [Brief description of this field]
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

/// MetroRouteScenarioRunner: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class MetroRouteScenarioRunner {
  MetroRouteScenarioRunner({
    this.config = const MetroRouteScenarioConfig(),
    this.destinationName = 'Sumadhura Shikharam',
  });

  /// [Brief description of this field]
  final MetroRouteScenarioConfig config;
  /// [Brief description of this field]
  final String destinationName;

  RouteSimulationController? _controller;
  bool _appliedOverrides = false;
  MetroScenarioSnapshot? _lastSnapshot;
  MetroScenarioRunOptions? _lastRun;

  MetroScenarioSnapshot? get lastSnapshot => _lastSnapshot;
  MetroScenarioRunOptions? get lastRunOptions => _lastRun;

  /// [Brief description of this field]
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

  /// [Brief description of this field]
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

  /// [Brief description of this field]
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

  /// [Brief description of this field]
  static const List<_MilestoneDefinition> _milestoneDefinitions = <_MilestoneDefinition>[
    /// _MilestoneDefinition: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _MilestoneDefinition(
      pointIndex: 1,
      id: 'board_nagasandra',
      type: 'mode_change',
      label: 'Board metro at Nagasandra',
    ),
    /// _MilestoneDefinition: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _MilestoneDefinition(
      pointIndex: 6,
      id: 'transfer_majestic',
      type: 'transfer',
      label: 'Change line at Majestic interchange',
    ),
    /// _MilestoneDefinition: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _MilestoneDefinition(
      pointIndex: 12,
      id: 'exit_whitefield',
      type: 'transfer',
      label: 'Prepare to exit at Whitefield metro',
    ),
    /// _MilestoneDefinition: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _MilestoneDefinition(
      pointIndex: 15,
      id: 'destination_arrival',
      type: 'destination',
      label: 'Arrive at Sumadhura Shikharam',
    ),
  ];

  /// [Brief description of this field]
  static final Map<int, _MilestoneDefinition> _milestonesByIndex = {
    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (final m in _milestoneDefinitions) m.pointIndex: m,
  };

  /// start: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<MetroScenarioSnapshot> start({MetroScenarioRunOptions? options}) async {
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (_controller != null) {
      /// stop: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      await stop();
    }

    /// defaults: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final run = options ?? MetroScenarioRunOptions.defaults(config);
    final controller = RouteSimulationController(
      polyline: _polyline,
      baseSpeedMps: config.baseSpeedMps,
      tickInterval: config.tickInterval,
    );
    _controller = controller;

    /// _computeMetrics: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final metrics = _computeMetrics();

    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (config.enableFullOrchestrator) {
      TrackingService.useOrchestratorForDestinationAlarm = true;
    }

    /// [Brief description of this field]
    final alarmMode = run.mode.value;
    /// switch: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final alarmValue = switch (run.mode) {
      MetroAlarmMode.distance => run.distanceMeters,
      MetroAlarmMode.stops => run.stopsThreshold,
      MetroAlarmMode.time => run.timeMinutes,
    };

    /// startTrackingWithSimulation: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await controller.startTrackingWithSimulation(
      destinationName: destinationName,
      alarmMode: alarmMode,
      alarmValue: alarmValue,
    );

    /// _applyScenarioOverrides: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    await _applyScenarioOverrides(
      totalLengthMeters: metrics.totalLengthMeters,
      routeEvents: metrics.events,
      totalStops: metrics.totalStops,
      eventWindowMeters: run.eventTriggerWindowMeters,
      stepBounds: metrics.stepBounds,
      stepStops: metrics.stepStops,
      milestones: metrics.milestones
          /// map: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
          .map((m) => {
                'id': m.id,
                'label': m.label,
                'type': m.type,
                'metersFromStart': m.metersFromStart,
                'cumulativeStops': m.cumulativeStops,
                'etaSeconds': m.etaSeconds,
              })
          /// toList: [Brief description of what this function does]
          /// 
          /// **Parameters**: [Describe parameters if any]
          /// **Returns**: [Describe return value]
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

    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (run.speedMultiplier != 1.0) {
      /// setSpeedMultiplier: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      controller.setSpeedMultiplier(run.speedMultiplier);
    }

    /// start: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
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

  /// stop: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  Future<void> stop() async {
    /// stop: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _controller?.stop();
    /// dispose: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _controller?.dispose();
    _controller = null;
    _appliedOverrides = false;
  }

  bool get isRunning => _controller != null;

  /// setSpeedMultiplier: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  void setSpeedMultiplier(double multiplier) {
    /// setSpeedMultiplier: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    _controller?.setSpeedMultiplier(multiplier);
  }

  /// _applyScenarioOverrides: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
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
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
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

  /// _computeMetrics: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  _ScenarioMetrics _computeMetrics() {
    double cumMeters = 0.0;
    double cumStops = 0.0;
    double cumSeconds = 0.0;
    /// [Brief description of this field]
    final events = <RouteEventBoundary>[];
    /// [Brief description of this field]
    final bounds = <double>[0.0];
    /// [Brief description of this field]
    final stops = <double>[0.0];
    /// [Brief description of this field]
    final milestones = <MetroScenarioMilestone>[];

    /// for: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    for (int i = 0; i < _polyline.length - 1; i++) {
      /// [Brief description of this field]
      final from = _polyline[i];
      /// [Brief description of this field]
      final to = _polyline[i + 1];
      /// distanceBetween: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      final segMeters = Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      final segSpeed = (i < _segmentSpeedMps.length && _segmentSpeedMps[i] > 0)
          ? _segmentSpeedMps[i]
          : config.baseSpeedMps;
      /// [Brief description of this field]
      final segSeconds = segSpeed <= 0 ? 0 : segMeters / segSpeed;

      cumMeters += segMeters;
      /// toDouble: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      cumStops += (i < _segmentStopAllocation.length) ? _segmentStopAllocation[i].toDouble() : 0.0;
      cumSeconds += segSeconds;

      /// [Brief description of this field]
      final milestoneDef = _milestonesByIndex[i + 1];
      /// if: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      if (milestoneDef != null) {
        /// add: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        events.add(RouteEventBoundary(
          meters: cumMeters,
          type: milestoneDef.type,
          label: milestoneDef.label,
        ));
        /// add: [Brief description of what this function does]
        /// 
        /// **Parameters**: [Describe parameters if any]
        /// **Returns**: [Describe return value]
        milestones.add(MetroScenarioMilestone(
          id: milestoneDef.id,
          label: milestoneDef.label,
          type: milestoneDef.type,
          metersFromStart: cumMeters,
          cumulativeStops: cumStops,
          etaSeconds: cumSeconds,
        ));
      }

      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      bounds.add(cumMeters);
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      stops.add(cumStops);
    }

    /// [Brief description of this field]
    final totalStops = stops.isNotEmpty ? stops.last : 0.0;
    /// [Brief description of this field]
    final totalDurationSeconds = cumSeconds;

    // Ensure destination milestone captured even if not in definitions
    /// any: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    final hasDestination = milestones.any((m) => m.id == 'destination_arrival');
    /// if: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
    if (!hasDestination) {
      /// add: [Brief description of what this function does]
      /// 
      /// **Parameters**: [Describe parameters if any]
      /// **Returns**: [Describe return value]
      milestones.add(MetroScenarioMilestone(
        id: 'destination_arrival',
        label: 'Arrive at destination',
        type: 'destination',
        metersFromStart: cumMeters,
        cumulativeStops: totalStops,
        etaSeconds: totalDurationSeconds,
      ));
    }

    /// _ScenarioMetrics: [Brief description of what this function does]
    /// 
    /// **Parameters**: [Describe parameters if any]
    /// **Returns**: [Describe return value]
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

/// _ScenarioMetrics: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _ScenarioMetrics {
  /// _ScenarioMetrics: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  const _ScenarioMetrics({
    required this.totalLengthMeters,
    required this.totalStops,
    required this.totalDurationSeconds,
    required this.events,
    required this.stepBounds,
    required this.stepStops,
    required this.milestones,
  });

  /// [Brief description of this field]
  final double totalLengthMeters;
  /// [Brief description of this field]
  final double totalStops;
  /// [Brief description of this field]
  final double totalDurationSeconds;
  /// [Brief description of this field]
  final List<RouteEventBoundary> events;
  /// [Brief description of this field]
  final List<double> stepBounds;
  /// [Brief description of this field]
  final List<double> stepStops;
  /// [Brief description of this field]
  final List<MetroScenarioMilestone> milestones;
}

/// _MilestoneDefinition: Class for [brief description]
/// 
/// **Purpose**: [What this class does]
/// 
/// **Usage**: [How to use this class]
class _MilestoneDefinition {
  /// _MilestoneDefinition: [Brief description of what this function does]
  /// 
  /// **Parameters**: [Describe parameters if any]
  /// **Returns**: [Describe return value]
  const _MilestoneDefinition({
    required this.pointIndex,
    required this.id,
    required this.type,
    required this.label,
  });

  /// [Brief description of this field]
  final int pointIndex;
  /// [Brief description of this field]
  final String id;
  /// [Brief description of this field]
  final String type;
  /// [Brief description of this field]
  final String label;
}
