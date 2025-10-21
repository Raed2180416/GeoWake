import 'dart:developer' as dev;

class RouteEventBoundary {
  final double meters;
  final String type; // 'transfer' | 'mode_change'
  final String? label; // e.g., station or mode label
  RouteEventBoundary({required this.meters, required this.type, this.label});
  Map<String, dynamic> toJson() => {
        'meters': meters,
        'type': type,
        if (label != null) 'label': label,
      };
  static RouteEventBoundary fromJson(Map<String, dynamic> m) => RouteEventBoundary(
        meters: (m['meters'] as num).toDouble(),
        type: m['type'] as String,
        label: m['label'] as String?,
      );
}

class TransferUtils {
  static List<double> buildTransferBoundariesMeters(Map<String, dynamic> directions, {bool metroMode = false}) {
    final result = <double>[];
    if (!metroMode) return result;
    try {
      final routes = (directions['routes'] as List?) ?? const [];
      if (routes.isEmpty) return result;
      final route = routes.first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      double cum = 0.0;
      for (final leg in legs) {
        final steps = (leg['steps'] as List?) ?? const [];
        for (int i = 0; i < steps.length; i++) {
          final step = steps[i] as Map<String, dynamic>;
          final dist = ((step['distance'] as Map<String, dynamic>?)?['value']) as num?;
          final mode = step['travel_mode'] as String?;
          if (dist != null) cum += dist.toDouble();
          if (mode == 'TRANSIT') {
            // Identify current line id
            final curLine = ((step['transit_details'] as Map<String, dynamic>?)?['line']) as Map<String, dynamic>?;
            final curId = (curLine?['short_name'] ?? curLine?['name'] ?? curLine?['id'])?.toString();
            if (curId == null) continue;
            // Look ahead to the next transit step (skipping walking)
            String? nextTransitId;
            for (int j = i + 1; j < steps.length; j++) {
              final nextStep = steps[j] as Map<String, dynamic>;
              final nextMode = nextStep['travel_mode'] as String?;
              if (nextMode == 'TRANSIT') {
                final nxtLine = ((nextStep['transit_details'] as Map<String, dynamic>?)?['line']) as Map<String, dynamic>?;
                nextTransitId = (nxtLine?['short_name'] ?? nxtLine?['name'] ?? nxtLine?['id'])?.toString();
                break;
              }
            }
            if (nextTransitId != null && nextTransitId != curId) {
              // Boundary at the end of current transit step
              result.add(cum);
            }
          }
        }
      }
    } catch (e) {
      dev.log('Failed to compute transfer boundaries: $e', name: 'TransferUtils');
    }
    return result;
  }

  // Build rich event boundaries for transfers and mode changes along the route.
  static List<RouteEventBoundary> buildRouteEvents(Map<String, dynamic> directions) {
    final events = <RouteEventBoundary>[];
    try {
      final routes = (directions['routes'] as List?) ?? const [];
      if (routes.isEmpty) return events;
      final route = routes.first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      double cum = 0.0;
      String? prevMode;
      for (final leg in legs) {
        final steps = (leg['steps'] as List?) ?? const [];
        for (int i = 0; i < steps.length; i++) {
          final step = steps[i] as Map<String, dynamic>;
          final mode = step['travel_mode'] as String?;
          final dist = ((step['distance'] as Map<String, dynamic>?)?['value']) as num?;

          // Mode change event recorded at the boundary between steps (before adding current step distance)
          if (prevMode != null && mode != null && mode != prevMode) {
            final label = _modeLabel(mode);
            events.add(RouteEventBoundary(meters: cum, type: 'mode_change', label: label));
            // Log mode change detection for verification
            dev.log('Detected mode change at ${cum.toStringAsFixed(1)}m: $prevMode -> $mode', 
                   name: 'TransferUtils');
          }
          if (dist != null) cum += dist.toDouble();

          // Transfer event inside TRANSIT: when next transit line differs
          if (mode == 'TRANSIT') {
            final curLine = ((step['transit_details'] as Map<String, dynamic>?)?['line']) as Map<String, dynamic>?;
            final curId = (curLine?['short_name'] ?? curLine?['name'] ?? curLine?['id'])?.toString();
            String? nextTransitId;
            String? arrivalStopName;
            // Use this step's arrival_stop as the transfer label if available
            final arrivalStop = ((step['transit_details'] as Map<String, dynamic>?)?['arrival_stop']) as Map<String, dynamic>?;
            arrivalStopName = arrivalStop != null ? (arrivalStop['name'] as String?) : null;
            for (int j = i + 1; j < steps.length; j++) {
              final nextStep = steps[j] as Map<String, dynamic>;
              final nextMode = nextStep['travel_mode'] as String?;
              if (nextMode == 'TRANSIT') {
                final nxtLine = ((nextStep['transit_details'] as Map<String, dynamic>?)?['line']) as Map<String, dynamic>?;
                nextTransitId = (nxtLine?['short_name'] ?? nxtLine?['name'] ?? nxtLine?['id'])?.toString();
                break;
              }
            }
            if (curId != null && nextTransitId != null && nextTransitId != curId) {
              events.add(RouteEventBoundary(meters: cum, type: 'transfer', label: arrivalStopName));
              // Log transfer detection for verification
              dev.log('Detected transit transfer at ${cum.toStringAsFixed(1)}m: $curId -> $nextTransitId at ${arrivalStopName ?? "unknown stop"}', 
                     name: 'TransferUtils');
            }
          }

          if (mode != null) prevMode = mode;
        }
      }
    } catch (e) {
      dev.log('Failed to compute route events: $e', name: 'TransferUtils');
    }
    // Deduplicate close events
    events.sort((a, b) => a.meters.compareTo(b.meters));
    final dedup = <RouteEventBoundary>[];
    double? lastM;
    for (final ev in events) {
      if (lastM == null || (ev.meters - lastM).abs() > 1.0) {
        dedup.add(ev);
        lastM = ev.meters;
      }
    }
    
    // Log summary for verification
    dev.log('Built ${dedup.length} route events: ${dedup.map((e) => "${e.type}@${e.meters.toStringAsFixed(0)}m").join(", ")}', 
           name: 'TransferUtils');
    
    return dedup;
  }

  // Returns a tuple-like map with step boundaries in meters (cumulative across all steps)
  // and cumulative stops at each boundary (TRANSIT steps add num_stops, others add 0).
  static ({List<double> bounds, List<double> stops}) buildStepBoundariesAndStops(Map<String, dynamic> directions) {
    final bounds = <double>[];
    final stops = <double>[];
    try {
      final routes = (directions['routes'] as List?) ?? const [];
  if (routes.isEmpty) return (bounds: bounds, stops: stops);
      final route = routes.first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      double cumM = 0.0;
      double cumStops = 0.0;
      for (final leg in legs) {
        final steps = (leg['steps'] as List?) ?? const [];
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          final dist = ((step['distance'] as Map<String, dynamic>?)?['value']) as num?;
          if (dist != null) cumM += dist.toDouble();
          if (step['travel_mode'] == 'TRANSIT') {
            final td = (step['transit_details'] as Map<String, dynamic>?);
            final ns = td != null ? td['num_stops'] as num? : null;
            if (ns != null) cumStops += ns.toDouble();
          }
          bounds.add(cumM);
          stops.add(cumStops);
        }
      }
    } catch (e) {
      dev.log('Failed to compute step boundaries/stops: $e', name: 'TransferUtils');
    }
    return (bounds: bounds, stops: stops);
  }

  static String _modeLabel(String mode) {
    switch (mode) {
      case 'WALKING':
        return 'Start walking';
      case 'DRIVING':
        return 'Start driving';
      case 'TRANSIT':
        return 'Board transit';
      case 'BICYCLING':
        return 'Start cycling';
      default:
        return mode;
    }
  }

  /// Verifies that all critical switch points are captured in route events.
  /// Returns a verification report with any missing switch points.
  static Map<String, dynamic> verifySwitchPointCoverage(Map<String, dynamic> directions) {
    final report = <String, dynamic>{
      'totalSwitchPoints': 0,
      'capturedInEvents': 0,
      'missingSwitchPoints': <String>[],
      'allEventsCaptured': true,
    };

    try {
      final routes = (directions['routes'] as List?) ?? const [];
      if (routes.isEmpty) return report;
      
      final route = routes.first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      
      // Track all mode transitions and transfers
      final allSwitchPoints = <String>[];
      double cum = 0.0;
      String? prevMode;
      
      for (final leg in legs) {
        final steps = (leg['steps'] as List?) ?? const [];
        for (int i = 0; i < steps.length; i++) {
          final step = steps[i] as Map<String, dynamic>;
          final mode = step['travel_mode'] as String?;
          final dist = ((step['distance'] as Map<String, dynamic>?)?['value']) as num?;
          
          // Check for mode change
          if (prevMode != null && mode != null && mode != prevMode) {
            allSwitchPoints.add('mode_change@${cum.toStringAsFixed(1)}:$prevMode->$mode');
          }
          
          if (dist != null) cum += dist.toDouble();
          
          // Check for transit transfer
          if (mode == 'TRANSIT') {
            final curLine = ((step['transit_details'] as Map<String, dynamic>?)?['line']) as Map<String, dynamic>?;
            final curId = (curLine?['short_name'] ?? curLine?['name'] ?? curLine?['id'])?.toString();
            
            for (int j = i + 1; j < steps.length; j++) {
              final nextStep = steps[j] as Map<String, dynamic>;
              final nextMode = nextStep['travel_mode'] as String?;
              if (nextMode == 'TRANSIT') {
                final nxtLine = ((nextStep['transit_details'] as Map<String, dynamic>?)?['line']) as Map<String, dynamic>?;
                final nextTransitId = (nxtLine?['short_name'] ?? nxtLine?['name'] ?? nxtLine?['id'])?.toString();
                if (curId != null && nextTransitId != null && nextTransitId != curId) {
                  allSwitchPoints.add('transfer@${cum.toStringAsFixed(1)}:$curId->$nextTransitId');
                }
                break;
              }
            }
          }
          
          if (mode != null) prevMode = mode;
        }
      }
      
      report['totalSwitchPoints'] = allSwitchPoints.length;
      
      // Verify against built events
      final events = buildRouteEvents(directions);
      report['capturedInEvents'] = events.length;
      
      // Check if all switch points are captured
      if (allSwitchPoints.length > events.length) {
        report['allEventsCaptured'] = false;
        dev.log('WARNING: Potential missing switch points detected. Expected ${allSwitchPoints.length}, got ${events.length} events', 
               name: 'TransferUtils.Verification');
      }
      
    } catch (e) {
      dev.log('Failed to verify switch point coverage: $e', name: 'TransferUtils.Verification');
      report['error'] = e.toString();
    }
    
    return report;
  }

  // Identify the cumulative stops at the first boarding of a TRANSIT segment.
  static double? firstTransitBoardingStops(Map<String, dynamic> directions) {
    try {
      final routes = (directions['routes'] as List?) ?? const [];
      if (routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      double cumStops = 0.0;
      for (final leg in legs) {
        final steps = (leg['steps'] as List?) ?? const [];
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          if (step['travel_mode'] == 'TRANSIT') {
            return cumStops; // stops before boarding first transit
          }
          if (step['travel_mode'] == 'TRANSIT') {
            final td = (step['transit_details'] as Map<String, dynamic>?);
            final ns = td != null ? td['num_stops'] as num? : null;
            if (ns != null) cumStops += ns.toDouble();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Compute the target cumulative stops for an alert N stops prior to a given event index
  // in the events list (e.g., transfer or final arrival). Returns cumulative stop counts.
  static double? nStopsPriorTarget({
    required ({List<double> bounds, List<double> stops}) stepData,
    required List<RouteEventBoundary> events,
    required int eventIndex,
    required double nStops,
  }) {
    if (eventIndex < 0 || eventIndex >= events.length) return null;
    final evM = events[eventIndex].meters;
    // Find cumulative stops at event boundary
    double? evStops;
    for (int i = 0; i < stepData.bounds.length; i++) {
      if (evM <= stepData.bounds[i]) {
        evStops = stepData.stops[i];
        break;
      }
    }
    if (evStops == null) return null;
    final targetStops = (evStops - nStops).clamp(0.0, double.infinity);
    return targetStops;
  }
}
