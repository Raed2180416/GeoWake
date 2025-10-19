part of 'package:geowake2/services/trackingservice.dart';

@pragma('vm:entry-point')
Future<void> _onStop() async {
  try { WidgetsFlutterBinding.ensureInitialized(); } catch (_) {}
  try { DartPluginRegistrant.ensureInitialized(); } catch (_) {}
  _positionSubscription?.cancel();
  _positionSubscription = null;
  _gpsCheckTimer?.cancel();
  _gpsCheckTimer = null;
  if (_sensorFusionManager != null) {
    _sensorFusionManager!.stopFusion();
    _sensorFusionManager!.dispose();
    _sensorFusionManager = null;
  }
  _fusionActive = false;
  // Dispose orchestrator subscription (dual‑run shadow)
  try {
    await _orchSub?.cancel();
  } catch (_) {}
  _orchSub = null;
  _mgrStateSub?.cancel();
  _mgrStateSub = null;
  _mgrSwitchSub?.cancel();
  _mgrSwitchSub = null;
  _devSub?.cancel();
  _devSub = null;
  _rerouteSub?.cancel();
  _rerouteSub = null;
  _activeManager?.dispose();
  _activeManager = null;
  _devMonitor?.dispose();
  _devMonitor = null;
  _reroutePolicy?.dispose();
  _reroutePolicy = null;
  // Stop progress heartbeat
  try { _progressHeartbeatTimer?.cancel(); } catch (_) {}
  _progressHeartbeatTimer = null;
  
  // Explicitly stop any playing alarm and vibration
  try {
    // Stop alarm sound
    await AlarmPlayer.stop();
    // Stop vibration
    NotificationService().stopVibration();
    
    // We'll rely on the NotificationService's cancelJourneyProgress() to handle
    // the progress notification, and the alarm notification should be handled
    // by AlarmPlayer.stop() and stopVibration()
  } catch (e) {
    dev.log('Error stopping alarm during tracking stop: $e', name: 'TrackingService');
  }
  
  // Cancel persistent progress notification
  try {
    if (!TrackingService.isTestMode) {
      await NotificationService().cancelJourneyProgress();
    }
  } catch (_) {}
  // Clear any persisted session state and fast flags to prevent unintended auto-resume on next launch
  try { await TrackingSessionStateFile.clear(); } catch (_) {}
  try { final prefs = await SharedPreferences.getInstance(); await prefs.setBool(TrackingSessionStateFile.trackingActiveFlagKey, false); await prefs.setBool(TrackingService.resumePendingFlagKey, false); } catch (_) {}
  TrackingService.autoResumed = false;
  dev.log("Tracking has been fully stopped.", name: "TrackingService");
}

// Heartbeat timer to refresh progress notification and emit position updates for UI harness
Timer? _progressHeartbeatTimer;
void _startProgressHeartbeat(ServiceInstance service) {
  try { _progressHeartbeatTimer?.cancel(); } catch (_) {}
  // Use 5 second heartbeat for more aggressive notification persistence
  // This ensures the notification is refreshed frequently even when app is backgrounded
  _progressHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
    // Check if native END_TRACKING was triggered
    try {
      final prefs = await SharedPreferences.getInstance();
      final nativeEndSignal = prefs.getBool('flutter.native_end_tracking_signal_v1') ?? false;
      if (nativeEndSignal) {
        dev.log('Native END_TRACKING signal detected - stopping service', name: 'TrackingService');
        await prefs.remove('flutter.native_end_tracking_signal_v1');
        
        // CRITICAL: Notify foreground isolate so UI can update
        try {
          service.invoke('trackingStopped', {'reason': 'native_notification_button'});
          dev.log('Sent trackingStopped event to foreground', name: 'TrackingService');
        } catch (e) {
          dev.log('Error sending trackingStopped event: $e', name: 'TrackingService');
        }
        
  await _onStop();
        service.stopSelf();
        return;
      }
    } catch (e) {
      dev.log('Error checking native END_TRACKING signal: $e', name: 'TrackingService');
    }
    
    // CRITICAL: Always ensure service is in foreground mode first
    // This prevents the service from being killed when app is swiped away
    try {
      final dynamic dynService = service;
      bool shouldElevate = false;
      try {
        final bool? isFg = await dynService.isForegroundService();
        shouldElevate = isFg == false;
      } catch (_) {}
      if (shouldElevate) {
        dev.log('Progress heartbeat detected non-foreground service; re-elevating.', name: 'TrackingService');
        try { 
          await dynService.setAsForegroundService(); 
          dev.log('Service re-elevated to foreground', name: 'TrackingService');
        } catch (e) {
          dev.log('Failed to re-elevate service: $e', name: 'TrackingService');
        }
      }
    } catch (_) {}
    
    // Re-post progress notification if tracking is active and not suppressed
    try {
      final suppressed = TrackingService.suppressProgressNotifications || await TrackingService.isProgressSuppressed();
      if (!TrackingService.isTestMode && !suppressed) {
        final snapshot = _buildProgressSnapshot();
        if (snapshot != null) {
          try {
            await NotificationService().persistProgressSnapshot(
              title: snapshot['title'] as String,
              subtitle: snapshot['subtitle'] as String,
              progress: snapshot['progress'] as double,
            );
          } catch (_) {}
          try {
            await NotificationService().showJourneyProgress(
              title: snapshot['title'] as String,
              subtitle: snapshot['subtitle'] as String,
              progress0to1: snapshot['progress'] as double,
            );
          } catch (e) {
            dev.log('Failed to show progress notification in heartbeat: $e', name: 'TrackingService');
          }
        }
        try { await NotificationService().ensureProgressNotificationPresent(); } catch (_) {}
      }
    } catch (_) {}
    // Emit light-weight position update for diagnostics harness map UI
    try {
      if (_lastProcessedPosition != null) {
        service.invoke('positionUpdate', {
          'lat': _lastProcessedPosition!.latitude,
          'lng': _lastProcessedPosition!.longitude,
          'ts': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  });
  dev.log('Progress heartbeat started with 5-second interval', name: 'TrackingService');
}

Map<String, dynamic>? _buildProgressSnapshot({ActiveRouteState? stateOverride}) {
  final state = stateOverride ?? _lastActiveState;
  if (state == null) return null;
  final total = state.progressMeters + state.remainingMeters;
  if (!total.isFinite || total <= 0) return null;
  final frac = (state.progressMeters / total).clamp(0.0, 1.0);
  final remainingM = state.remainingMeters;
  final remainingKm = (remainingM / 1000.0).toStringAsFixed(1);
  String subtitle = 'Remaining: $remainingKm km';
  if (_smoothedETA != null && _smoothedETA!.isFinite) {
    final etaSec = _smoothedETA!;
    String etaStr;
    if (etaSec < 90) {
      etaStr = '${etaSec.toStringAsFixed(0)}s';
    } else if (etaSec < 3600) {
      etaStr = '${(etaSec / 60).toStringAsFixed(0)}m';
    } else {
      etaStr = '${(etaSec / 3600).toStringAsFixed(1)}h';
    }
    subtitle = 'Remaining: $remainingKm km · ETA $etaStr';
  }
  final title = _destinationName != null ? 'Journey to $_destinationName' : 'GeoWake journey';
  return {
    'title': title,
    'subtitle': subtitle,
    'progress': frac,
  };
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service, {Map<String, dynamic>? initialData}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try { DartPluginRegistrant.ensureInitialized(); } catch (_) {}
  if (service is AndroidServiceInstance) {
    try { service.setAsForegroundService(); } catch (_) {}
    // NOTE: We deliberately use a minimal notification here
    // The actual progress notification with action buttons will be shown
    // via NotificationService.showJourneyProgress() which uses ID 888
    // and properly configured PendingIntents for the action buttons
    try {
    } catch (_) {}
  }
  try {
    await NotificationService().initialize();
  } catch (_) {}
  // Start a light heartbeat to re-post progress notification and emit position updates.
  _startProgressHeartbeat(service);
  // Early fast-flag read when background isolate boots
  try {
    final prefs = await SharedPreferences.getInstance();
    final fast = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey);
    print('GW_ARES_FLAG_READ bgBoot=$fast');
    if (!TrackingService.isTestMode) {
      try {
        final resume = prefs.getBool(TrackingService.resumePendingFlagKey);
        print('GW_ARES_RESUME_FLAG_READ bgBoot=$resume');
      } catch (e) { print('GW_ARES_RESUME_FLAG_READ_FAIL bgBoot err=$e'); }
    } else {
      print('GW_ARES_RESUME_FLAG_READ bgBoot=TEST_SKIP');
    }
  } catch (e) { print('GW_ARES_FLAG_READ_FAIL bgBoot err=$e'); }

  // Respond to foreground requests for current session parameters (recovery path)
  try {
    service.on('requestSessionInfo').listen((event) {
      try {
        if (_destination != null && _destinationName != null && _alarmMode != null && _alarmValue != null) {
          service.invoke('sessionInfo', {
            'destinationLat': _destination!.latitude,
            'destinationLng': _destination!.longitude,
            'destinationName': _destinationName,
            'alarmMode': _alarmMode,
            'alarmValue': _alarmValue,
          });
        } else {
          service.invoke('sessionInfo', {'empty': true});
        }
      } catch (_) {
        try { service.invoke('sessionInfo', {'error': true}); } catch (_) {}
      }
    });
  } catch (_) {}

  // Snapshot effective minSinceStart at start (test override vs thresholds) for consistency
  try {
    final thresholds = ThresholdsProvider.current;
    _effectiveMinSinceStart = TrackingService.timeAlarmMinSinceStart != const Duration(seconds: 30)
        ? TrackingService.timeAlarmMinSinceStart
        : thresholds.minSinceStart;
  } catch (_) {}
  
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('startTracking').listen((data) async {
    if (data != null) {
      _emitLogSchemaOnce();
      _destination = LatLng(data['destinationLat'], data['destinationLng']);
      _destinationName = data['destinationName'];
      _alarmMode = data['alarmMode'];
      _alarmValue = (data['alarmValue'] as num).toDouble();
      // Background-side redundancy persistence (covers foreground crash before save)
      if (!(TrackingService.isTestMode && TrackingService.suppressPersistenceInTest)) {
        try {
          print('GW_ARES_BG_PERSIST_ATTEMPT');
          TrackingSessionStateFile.save({
            'destinationLat': _destination!.latitude,
            'destinationLng': _destination!.longitude,
            'destinationName': _destinationName,
            'alarmMode': _alarmMode,
            'alarmValue': _alarmValue,
            'startedAt': DateTime.now().millisecondsSinceEpoch,
          }).then((_) => print('GW_ARES_BG_PERSIST_OK'))
            .catchError((e) { print('GW_ARES_BG_PERSIST_FAIL err=$e'); });
        } catch (e) { print('GW_ARES_BG_PERSIST_EXCEPTION err=$e'); }
      } else {
        print('GW_ARES_BG_PERSIST_TEST_SKIP');
      }
      // Verify fast flag after scheduling background persistence
      if (!(TrackingService.isTestMode && TrackingService.suppressPersistenceInTest)) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final fast = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey);
          print('GW_ARES_FLAG_READ postBGPersist=$fast');
          if (!TrackingService.isTestMode) {
            try {
              await prefs.setBool(TrackingService.resumePendingFlagKey, true);
              print('GW_ARES_RESUME_FLAG_SET val=true phase=startTrackingBackground');
            } catch (e) { print('GW_ARES_RESUME_FLAG_FAIL val=true phase=startTrackingBackground err=$e'); }
          } else {
            print('GW_ARES_RESUME_FLAG_SET val=true phase=startTrackingBackground TEST_SKIP');
          }
        } catch (e) { print('GW_ARES_FLAG_READ_FAIL postBGPersist err=$e'); }
      } else {
        print('GW_ARES_FLAG_READ_TEST_SKIP postBGPersist');
      }
      // Initialize dual‑run orchestrator
      try {
        _orchestrator ??= AlarmOrchestratorImpl(
          requiredPasses: _proximityRequiredPasses,
          minDwell: _proximityMinDwell,
        );
        final cfg = _makeAlarmConfig();
        // Because time mode maps value differently, patch time threshold directly
        if (_alarmMode == 'time') {
          // copyWith helper used to set timeETALimitSeconds = minutes->seconds
          final patched = cfg.copyWith(timeETALimitSeconds: (_alarmValue ?? 0) * 60.0);
          _orchestrator!.configure(patched);
        } else {
          _orchestrator!.configure(cfg);
        }
        if (_destination != null && _destinationName != null) {
          _orchestrator!.registerDestination(DestinationSpec(lat: _destination!.latitude, lng: _destination!.longitude, name: _destinationName!));
          _syncOrchestratorGating();
          final restoredState = _asStringKeyedMap(data['orchestratorState']);
          if (restoredState != null) {
            _restoreOrchestratorStateFrom(restoredState);
          }
          // Attempt restore after destination registration
          try {
            if (TrackingService.sessionStore != null) {
              TrackingService.sessionStore!.load().then((snap) {
                // Currently only restore minimal progress-related fields (future: orchestrator internal state)
              });
            }
          } catch (_) {}
        }
        // Inject metrics if already present (e.g., route registered before startTracking call in tests)
        try {
          if (_activeManager != null && _registry.entries.isNotEmpty) {
            final e = _registry.entries.first;
            _orchestrator!.setTotalRouteMeters(e.lengthMeters);
          }
          if (_stepStopsCumulative.isNotEmpty) {
            _orchestrator!.setTotalStops(_stepStopsCumulative.last);
          }
        } catch (_) {}
        // Subscribe to events (test parity logging only for now)
        _orchSub ??= _orchestrator!.events$.listen((ev) {
          _handleOrchestratorEvent(service, ev);
        });
      } catch (_) {}
      // If caller requested injected positions, enable before starting stream
      try {
        if (data['useInjectedPositions'] == true) {
          _useInjectedPositions = true;
          _injectedCtrl ??= StreamController<Position>.broadcast();
        }
      } catch (_) {}
  _destinationAlarmFired = false; // Reset flags for a new trip
  _proximityConsecutivePasses = 0;
  _proximityFirstPassAt = null;
  _firedEventIndexes.clear();
      // Reset time-alarm gating state
      _startedAt = DateTime.now();
      _startPosition = null;
      _distanceTravelledMeters = 0.0;
      _etaSamples = 0;
      _timeAlarmEligible = false;
      _smoothedETA = null; // Reset ETA
      dev.log("Tracking started with params: Dest='$_destinationName', Mode='$_alarmMode', Value='$_alarmValue'", name: "TrackingService");
      // Show initial journey notification immediately
      try {
        if (!TrackingService.isTestMode) {
          NotificationService().showJourneyProgress(
            title: _destinationName != null ? 'Journey to $_destinationName' : 'GeoWake journey',
            subtitle: 'Starting…',
            progress0to1: 0.0,
          );
        }
      } catch (_) {}
      startLocationStream(service);
    }
  });

  // Enable injected positions (used by demo)
  service.on('useInjectedPositions').listen((event) {
    _useInjectedPositions = true;
    _injectedCtrl ??= StreamController<Position>.broadcast();
  });
  // Inject synthetic cumulative stops (diagnostics UI)
  service.on('injectSyntheticStops').listen((event) {
    try {
      final vals = ((event?['stops'] as List?) ?? []).cast<num>().map((n) => n.toDouble()).toList();
      if (vals.isNotEmpty) {
        _stepStopsCumulative = vals;
        // best-effort: emit integrity log and notify
        try { AppLogger.I.debug('STOPS_DATA', domain: 'stops', context: {
          'count': _stepStopsCumulative.length,
          'totalStops': _stepStopsCumulative.last,
          'source': 'injected',
        }); } catch (_) {}
      }
    } catch (_) {}
  });
  service.on('applyScenarioOverrides').listen((event) {
    try {
      final eventsRaw = (event?['events'] as List?) ?? const [];
      final parsedEvents = <RouteEventBoundary>[];
      for (final raw in eventsRaw) {
        if (raw is Map) {
          final mapped = raw.map((key, value) => MapEntry(key.toString(), value));
          parsedEvents.add(RouteEventBoundary.fromJson(mapped));
        }
      }
      if (parsedEvents.isNotEmpty) {
        _routeEvents = parsedEvents;
        _orchestrator?.setRouteEvents(parsedEvents);
        _firedEventIndexes.clear();
      }

      final boundsRaw = (event?['stepBounds'] as List?) ?? const [];
      if (boundsRaw.isNotEmpty) {
        _stepBoundsMeters = boundsRaw.map((e) => (e as num).toDouble()).toList();
      }

      final stopsRaw = (event?['stepStops'] as List?) ?? const [];
      if (stopsRaw.isNotEmpty) {
        _stepStopsCumulative = stopsRaw.map((e) => (e as num).toDouble()).toList();
        if (_stepStopsCumulative.isNotEmpty) {
          _orchestrator?.setTotalStops(_stepStopsCumulative.last);
          try { AppLogger.I.debug('STOPS_DATA', domain: 'stops', context: {
            'count': _stepStopsCumulative.length,
            'totalStops': _stepStopsCumulative.last,
            'source': 'scenario',
          }); } catch (_) {}
        }
      }

      final totalStops = event?['totalStops'] as num?;
      if (totalStops != null) {
        _orchestrator?.setTotalStops(totalStops.toDouble());
      }

      final totalRouteMeters = event?['totalRouteMeters'] as num?;
      if (totalRouteMeters != null) {
        _orchestrator?.setTotalRouteMeters(totalRouteMeters.toDouble());
      }

      final eventWindowMeters = event?['eventTriggerWindowMeters'] as num?;
      if (eventWindowMeters != null) {
        _orchestrator?.setEventTriggerWindowMeters(eventWindowMeters.toDouble());
      }

      final milestonesRaw = (event?['milestones'] as List?) ?? const [];
      if (milestonesRaw.isNotEmpty) {
        _scenarioMilestones = milestonesRaw
            .whereType<Map>()
            .map((m) => m.map((key, value) => MapEntry(key.toString(), value)))
            .toList(growable: false);
        try {
          AppLogger.I.debug('Scenario milestones received', domain: 'scenario', context: {
            'count': _scenarioMilestones.length,
          });
        } catch (_) {}
      } else {
        _scenarioMilestones = const [];
      }

      final totalSeconds = event?['totalDurationSeconds'] as num?;
      _scenarioTotalDurationSeconds = totalSeconds?.toDouble();

      final runConfigRaw = event?['runConfig'];
      if (runConfigRaw is Map) {
        _scenarioRunConfig = runConfigRaw.map((key, value) => MapEntry(key.toString(), value));
      }
      if (_scenarioTotalDurationSeconds != null || _scenarioRunConfig != null) {
        try {
          AppLogger.I.debug('Scenario config applied', domain: 'scenario', context: {
            if (_scenarioTotalDurationSeconds != null) 'totalSeconds': _scenarioTotalDurationSeconds,
            if (_scenarioRunConfig != null) 'runConfig': _scenarioRunConfig,
          });
        } catch (_) {}
      }

      try { service.invoke('scenarioOverridesApplied', {'ok': true}); } catch (_) {}
    } catch (e, st) {
      dev.log('Failed to apply scenario overrides: $e', name: 'TrackingService', stackTrace: st);
      try { service.invoke('scenarioOverridesApplied', {
        'error': e.toString(),
      }); } catch (_) {}
    }
  });
  // Inject a single position sample
  service.on('injectPosition').listen((data) {
    try {
      if (_injectedCtrl == null) {
        _injectedCtrl = StreamController<Position>.broadcast();
      }
      if (data == null) return;
      final p = Position(
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        timestamp: DateTime.now(),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 5.0,
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0.0,
        altitudeAccuracy: (data['altitudeAccuracy'] as num?)?.toDouble() ?? 0.0,
        heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
        headingAccuracy: (data['headingAccuracy'] as num?)?.toDouble() ?? 0.0,
        speed: (data['speed'] as num?)?.toDouble() ?? 12.0,
        speedAccuracy: (data['speedAccuracy'] as num?)?.toDouble() ?? 1.0,
      );
      _injectedCtrl!.add(p);
    } catch (_) {}
  });

  // Handle data passed directly (for test mode)
  if (initialData != null) {
      _destination = LatLng(initialData['destinationLat'], initialData['destinationLng']);
      _destinationName = initialData['destinationName'];
      _alarmMode = initialData['alarmMode'];
      _alarmValue = (initialData['alarmValue'] as num).toDouble();
      // Persist & verify for initialData path (test / cold start path)
      if (!(TrackingService.isTestMode && TrackingService.suppressPersistenceInTest)) {
        try {
          print('GW_ARES_INITDATA_PERSIST_ATTEMPT');
          await TrackingSessionStateFile.save({
            'destinationLat': _destination!.latitude,
            'destinationLng': _destination!.longitude,
            'destinationName': _destinationName,
            'alarmMode': _alarmMode,
            'alarmValue': _alarmValue,
            'startedAt': DateTime.now().millisecondsSinceEpoch,
          });
          print('GW_ARES_INITDATA_PERSIST_OK');
          await TrackingService._setResumePending(true, phase: 'initialDataPath');
        } catch (e) { print('GW_ARES_INITDATA_PERSIST_FAIL err=$e'); }
        try {
          final prefs = await SharedPreferences.getInstance();
          final fast = prefs.getBool(TrackingSessionStateFile.trackingActiveFlagKey);
          print('GW_ARES_FLAG_READ postInitData=$fast');
        } catch (e) { print('GW_ARES_FLAG_READ_FAIL postInitData err=$e'); }
      } else {
        print('GW_ARES_INITDATA_PERSIST_TEST_SKIP');
      }
      try {
        _orchestrator ??= AlarmOrchestratorImpl(
          requiredPasses: _proximityRequiredPasses,
          minDwell: _proximityMinDwell,
        );
        final cfg = _makeAlarmConfig();
        if (_alarmMode == 'time') {
          final patched = cfg.copyWith(timeETALimitSeconds: (_alarmValue ?? 0) * 60.0);
          _orchestrator!.configure(patched);
        } else {
          _orchestrator!.configure(cfg);
        }
        if (_destination != null && _destinationName != null) {
          _orchestrator!.registerDestination(DestinationSpec(lat: _destination!.latitude, lng: _destination!.longitude, name: _destinationName!));
          _syncOrchestratorGating();
          final restoredState = _asStringKeyedMap(initialData['orchestratorState']);
          if (restoredState != null) {
            _restoreOrchestratorStateFrom(restoredState);
          }
        }
        if (_activeManager != null && _registry.entries.isNotEmpty) {
          final e = _registry.entries.first;
          _orchestrator!.setTotalRouteMeters(e.lengthMeters);
        }
        if (_stepStopsCumulative.isNotEmpty) {
          _orchestrator!.setTotalStops(_stepStopsCumulative.last);
        }
        _orchSub ??= _orchestrator!.events$.listen((ev) {
          _handleOrchestratorEvent(service, ev);
        });
      } catch (_) {}
      try {
        if (initialData['useInjectedPositions'] == true) {
          _useInjectedPositions = true;
          _injectedCtrl ??= StreamController<Position>.broadcast();
        }
      } catch (_) {}
  _destinationAlarmFired = false;
  _firedEventIndexes.clear();
    // Reset time-alarm gating state
    _startedAt = DateTime.now();
    _startPosition = null;
    _distanceTravelledMeters = 0.0;
    _etaSamples = 0;
    _timeAlarmEligible = false;
    startLocationStream(service);
  }
  
  service.on("stopTracking").listen((event) async {
    // Make sure to stop the alarm explicitly first
    try {
      await AlarmPlayer.stop();
    } catch (e) {
      dev.log('Error stopping alarm during tracking stop: $e', name: 'TrackingService');
    }
    
    // Then stop all tracking
  await _onStop();
    // Persist suppression to silence any late progress updates from background side
    try { await TrackingService.setProgressSuppressed(true); } catch (_) {}
    
    if(event?['stopSelf'] == true){
       service.stopSelf();
    }
  });

  service.on('stopAlarm').listen((event) async {
    dev.log('Received stopAlarm event in background service', name: 'TrackingService');
    try { 
      // Stop playing sound
      await AlarmPlayer.stop();
      // Stop vibration through the notification service
      try {
        NotificationService().stopVibration();
      } catch (e) {
        dev.log('Error stopping vibration: $e', name: 'TrackingService');
      }
    } catch (_) {}
  });

  dev.log("Background Service Instance Started", name: "TrackingService");
}

SnappedPosition? _currentSnappedPositionForOrchestrator(Position position) {
  try {
    if (_lastActiveState != null) {
      int segmentIndex = 0;
      try {
        final entry = _registry.entries.firstWhere(
          (e) => e.key == _lastActiveState!.activeKey,
          orElse: () => _registry.entries.first,
        );
        segmentIndex = entry.lastSnapIndex ?? segmentIndex;
      } catch (_) {}
      return SnappedPosition(
        lat: _lastActiveState!.snapped.latitude,
        lng: _lastActiveState!.snapped.longitude,
        routeId: _lastActiveState!.activeKey,
        progressMeters: _lastActiveState!.progressMeters,
        lateralOffsetMeters: _lastActiveState!.offsetMeters,
        segmentIndex: segmentIndex,
      );
    }
    final entries = _registry.entries;
    if (entries.isNotEmpty) {
      final activeEntry = entries.first;
      final snap = SnapToRouteEngine.snap(
        point: LatLng(position.latitude, position.longitude),
        polyline: activeEntry.points,
        precomputedCumMeters: activeEntry.cumMeters,
        hintIndex: activeEntry.lastSnapIndex,
        lastProgress: activeEntry.lastProgressMeters,
      );
      _registry.updateSessionState(
        activeEntry.key,
        lastSnapIndex: snap.segmentIndex,
        lastProgressMeters: snap.progressMeters,
      );
      return SnappedPosition(
        lat: snap.snappedPoint.latitude,
        lng: snap.snappedPoint.longitude,
        routeId: activeEntry.key,
        progressMeters: snap.progressMeters,
        lateralOffsetMeters: snap.lateralOffsetMeters,
        segmentIndex: snap.segmentIndex,
      );
    }
  } catch (_) {}
  return null;
}

bool _shouldEnableProximityGating() {
  if (_alarmMode == 'time' && TrackingService.testBypassProximityForTime) {
    return false;
  }
  if (TrackingService.isTestMode && !TrackingService.testForceProximityGating) {
    return false;
  }
  return true;
}

void _syncOrchestratorGating() {
  if (_orchestrator == null) return;
  try {
    _orchestrator!.setProximityGatingEnabled(_shouldEnableProximityGating());
  } catch (_) {}
}

Map<String, dynamic>? _asStringKeyedMap(dynamic raw) {
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

void _restoreOrchestratorStateFrom(Map<String, dynamic> state) {
  if (_orchestrator == null) return;
  try {
    _orchestrator!.restoreState(state);
    final timeEligible = state['timeEligible'];
    if (timeEligible is bool) {
      _timeAlarmEligible = timeEligible;
    }
    if (state['fired'] == true) {
      _destinationAlarmFired = true;
    }
    final passes = state['proximityPasses'];
    if (passes is num) {
      _proximityConsecutivePasses = passes.toInt();
    }
    final firstPassAt = state['firstPassAt'];
    if (firstPassAt is String) {
      _proximityFirstPassAt = DateTime.tryParse(firstPassAt);
    }
    final etaSamples = state['etaSamples'];
    if (etaSamples is num) {
      _etaSamples = etaSamples.toInt();
    }
  } catch (_) {}
}

extension TrackingServiceRouteOps on TrackingService {
  // Public: update connectivity for reroute policy gating
  void setOnline(bool online) {
    _reroutePolicy?.setOnline(online);
    _offlineCoordinator?.setOffline(!online);
  }

  // Public: Register a fetched route into registry and initialize active manager if needed
  void registerRoute({
    required String key,
    required String mode,
    required String destinationName,
    required List<LatLng> points,
  }) {
    final entry = RouteEntry(
      key: key,
      mode: mode,
      destinationName: destinationName,
      points: points,
    );
    _registry.upsert(entry);
    // Initialize manager and pipelines if not exists
    _activeManager ??= ActiveRouteManager(
      registry: _registry,
      sustainDuration: TrackingService.isTestMode ? const Duration(milliseconds: 300) : const Duration(seconds: 6),
      switchMarginMeters: TrackingService.isTestMode ? 20 : 50,
      postSwitchBlackout: TrackingService.isTestMode ? const Duration(milliseconds: 300) : const Duration(seconds: 5),
    );
    _devMonitor ??= DeviationMonitor(
      sustainDuration: TrackingService.isTestMode ? const Duration(milliseconds: 300) : const Duration(seconds: 5),
    );
    // Cooldown from power policy will be applied in startLocationStream after battery read
    _reroutePolicy ??= ReroutePolicy(
      cooldown: TrackingService.isTestMode ? const Duration(seconds: 2) : const Duration(seconds: 20),
      initialOnline: true,
    );
    _offlineCoordinator ??= OfflineCoordinator(initialOffline: false);

    // Set this route as active if none
    if (!_activeRouteInitialized) {
      _activeManager!.setActive(key);
      _activeRouteInitialized = true;
    }

    // Bridge streams once
    _mgrStateSub ??= _activeManager!.stateStream.listen((s) {
      _routeStateCtrl.add(s);
      final spd = _lastSpeedMps ?? 0.0;
      double offForDeviation = s.offsetMeters;
        // Compute progress fraction (legacy or advanced)
        double? frac;
        if (FeatureFlags.advancedProjection && _lastProcessedPosition != null) {
          try {
            RouteEntry? entry;
            for (final e in _registry.entries) {
              if (e.key == s.activeKey) { entry = e; break; }
            }
            if (entry != null && entry.points.length >= 2) {
              final projector = _projectorCache.putIfAbsent(entry.key, () => SegmentProjector(entry!.points));
              final res = projector.project(LatLng(_lastProcessedPosition!.latitude, _lastProcessedPosition!.longitude));
              final totalLen = projector.totalLength <= 0 ? entry.lengthMeters : projector.totalLength;
              if (totalLen > 0) {
                frac = (res.progressMeters / totalLen).clamp(0.0, 1.0);
                _registry.updateSessionState(entry.key, lastProgressMeters: res.progressMeters, lastSnapIndex: res.segmentIndex);
              } else {
                frac = 0.0;
              }
            }
          } catch (_) {/* ignore */}
        }
        if (frac == null) {
          final total = (s.progressMeters + s.remainingMeters);
          if (total > 0) {
            frac = s.progressMeters / total;
          }
        }
        if (frac != null) {
          if (!TrackingService._progressCtrl.isClosed) {
            TrackingService._progressCtrl.add(frac.isFinite ? frac : null);
          }
          // Throttled notification update: send if >=300ms since last OR delta >=2%
          // Only update the foreground progress notification if:
          // 1. We are not in test mode (tests assert on timing without UI noise)
          // 2. The fraction is finite (avoid NaN/Infinity from division edge cases)
          // 3. The user has not pressed the IGNORE action (suppression flag)
          if (!TrackingService.isTestMode && frac.isFinite && !TrackingService.suppressProgressNotifications) {
            final now = DateTime.now();
            final dt = now.difference(TrackingService._lastProgressNotifyAt);
            final delta = (frac - TrackingService._lastNotifiedProgress).abs();
            if (TrackingService._lastNotifiedProgress < 0 || dt.inMilliseconds >= 500 || delta >= 0.01) {
              TrackingService._lastNotifiedProgress = frac;
              TrackingService._lastProgressNotifyAt = now;
              try {
                final remainingM = s.remainingMeters;
                final remainingKm = (remainingM / 1000.0).toStringAsFixed(1);
                String etaStr = '';
                if (_smoothedETA != null) {
                  final etaSec = _smoothedETA!;
                  if (etaSec < 90) {
                    etaStr = '${etaSec.toStringAsFixed(0)}s';
                  } else if (etaSec < 3600) {
                    etaStr = '${(etaSec / 60).toStringAsFixed(0)}m';
                  } else {
                    etaStr = '${(etaSec / 3600).toStringAsFixed(1)}h';
                  }
                }
                NotificationService().showJourneyProgress(
                  title: _destinationName != null ? 'Journey to $_destinationName' : 'GeoWake journey',
                  subtitle: etaStr.isNotEmpty ? 'Remaining: $remainingKm km · ETA $etaStr' : 'Remaining: $remainingKm km',
                  progress0to1: frac.clamp(0.0, 1.0),
                );
                if (TrackingService.enablePersistence) {
                  try {
                    TrackingService._persistence ??= PersistenceManager(baseDir: Directory.systemTemp.createTempSync());
                    final snap = TrackingSnapshot(
                      version: TrackingSnapshot.currentVersion,
                      timestampMs: DateTime.now().millisecondsSinceEpoch,
                      progress0to1: frac.isFinite ? frac : null,
                      etaSeconds: _smoothedETA,
                      distanceTravelledMeters: _distanceTravelledMeters,
                      destinationLat: _destination?.latitude,
                      destinationLng: _destination?.longitude,
                      destinationName: _destinationName,
                      activeRouteKey: s.activeKey,
                      fallbackScheduledEpochMs: TrackingService._fallbackManager?.reason != null ? 0 : null,
                      lastDestinationAlarmAtMs: _destinationAlarmFired ? DateTime.now().millisecondsSinceEpoch : null,
                      smoothedHeadingDeg: _smoothedHeadingDeg,
                      timeEligible: _timeAlarmEligible,
                      orchestratorState: _orchestrator != null
                          ? Map<String, dynamic>.from(_orchestrator!.toState())
                          : null,
                    );
                    // Fire and forget
                    // ignore: discarded_futures
                    TrackingService._persistence!.save(snap);
                  } catch (_) {}
                }
                // Tighten fallback schedule based on ETA (1.5x smoothed ETA) with debounce
                try {
                  if (TrackingService._fallbackManager != null && _smoothedETA != null && _smoothedETA!.isFinite) {
                    final now = DateTime.now();
                    if (now.difference(TrackingService._lastFallbackTighten) >= TrackingService._fallbackTightenDebounce) {
                      final etaSec = _smoothedETA!;
                      if (etaSec > 5) {
                        final desired = Duration(seconds: (etaSec * 1.5).round());
                        final minDelay = const Duration(minutes: 2);
                        final delay = desired < minDelay ? minDelay : desired;
                        // Fire and forget; if it schedules an earlier alarm internal logic keeps earliest
                        TrackingService._fallbackManager!.schedule(delay, reason: 'tighten_eta');
                        TrackingService._lastFallbackTighten = now;
                      }
                    }
                  }
                } catch (_) {}
              } catch (_) {}
            }
          }
  }
      try {
        if (_lastProcessedPosition != null) {
          final entry = _registry.entries.firstWhere((e) => e.key == s.activeKey, orElse: () => _registry.entries.first);
          final snap = SnapToRouteEngine.snap(point: _lastProcessedPosition!, polyline: entry.points, hintIndex: entry.lastSnapIndex);
          offForDeviation = snap.lateralOffsetMeters;
        }
      } catch (_) {}
      _devMonitor?.ingest(offsetMeters: offForDeviation, speedMps: spd);
      _lastActiveState = s;
      if (!TrackingService.isTestMode) {
        final data = _buildProgressSnapshot(stateOverride: s);
        if (data != null) {
          try {
            unawaited(NotificationService().persistProgressSnapshot(
              title: data['title'] as String,
              subtitle: data['subtitle'] as String,
              progress: data['progress'] as double,
            ));
          } catch (_) {}
        }
      }
      // Update route state in memory but let the timer handle notification updates
      // to prevent excessive notification updates that might get dropped
    });
    _mgrSwitchSub ??= _activeManager!.switchStream.listen((e) {
      _routeSwitchCtrl.add(e);
      try {
        _devMonitor?.reset();
      } catch (_) {}
    });
    _devSub ??= _devMonitor!.stream.listen((ds) async {
      double off = _lastActiveState?.offsetMeters ?? double.infinity;
      try {
        if (_lastProcessedPosition != null && _lastActiveState?.activeKey != null) {
          final entry = _registry.entries.firstWhere((e) => e.key == _lastActiveState!.activeKey, orElse: () => _registry.entries.first);
          final snap = SnapToRouteEngine.snap(point: _lastProcessedPosition!, polyline: entry.points, hintIndex: entry.lastSnapIndex);
          off = snap.lateralOffsetMeters;
        }
      } catch (_) {}

      // In tests, allow immediate local switch in the 100–150m band without waiting for sustain
      if (!ds.sustained) {
        if (off >= 100.0 && off <= 150.0) {
          try {
            if (_lastProcessedPosition != null && _registry.entries.isNotEmpty) {
              double bestOffset = off;
              RouteEntry? best;
              for (final e in _registry.entries) {
                final snap = SnapToRouteEngine.snap(point: _lastProcessedPosition!, polyline: e.points, hintIndex: e.lastSnapIndex);
                if (snap.lateralOffsetMeters + 1e-6 < bestOffset) {
                  bestOffset = snap.lateralOffsetMeters;
                  best = e;
                }
              }
              final margin = TrackingService.isTestMode ? 20.0 : 50.0;
              if (best != null && (off - bestOffset) >= margin) {
                final fromKey = _lastActiveState?.activeKey ?? 'unknown';
                _activeManager?.setActive(best.key);
                _routeSwitchCtrl.add(RouteSwitchEvent(fromKey: fromKey, toKey: best.key, at: DateTime.now()));
                return;
              }
            }
          } catch (_) {}
        }
        // Not sustained and not in immediate switch band
        return;
      }

      // Sustained deviation handling
      if (off < 100.0) {
        // Ignore minor noise; do not reroute
        return;
      }
      if (off <= 150.0) {
        // Prefer local switch to a better registered route; avoid network reroute
        try {
          if (_lastProcessedPosition != null && _registry.entries.isNotEmpty) {
            double bestOffset = off;
            RouteEntry? best;
            for (final e in _registry.entries) {
              final snap = SnapToRouteEngine.snap(point: _lastProcessedPosition!, polyline: e.points, hintIndex: e.lastSnapIndex);
              if (snap.lateralOffsetMeters + 1e-6 < bestOffset) {
                bestOffset = snap.lateralOffsetMeters;
                best = e;
              }
            }
            final margin = TrackingService.isTestMode ? 20.0 : 50.0;
            if (best != null && (off - bestOffset) >= margin) {
              final fromKey = _lastActiveState?.activeKey ?? 'unknown';
              _activeManager?.setActive(best.key);
              _routeSwitchCtrl.add(RouteSwitchEvent(fromKey: fromKey, toKey: best.key, at: DateTime.now()));
            }
          }
        } catch (_) {}
        return; // Do not trigger reroute
      }
      // >150m: allow reroute policy to decide (subject to cooldown/online)
      _reroutePolicy?.onSustainedDeviation(at: ds.at);
    });
    _rerouteSub ??= _reroutePolicy!.stream.listen((r) async {
      if (r.shouldReroute) {
        final startTs = DateTime.now();
        try { AppLogger.I.info('REROUTE_DECISION', domain: 'reroute', context: {
          'phase': 'start',
          'shouldReroute': r.shouldReroute,
          'at': r.at.toIso8601String(),
          'ts': startTs.toIso8601String(),
        }); } catch (_) {}
        if (TrackingService.isTestMode) {
          _rerouteCtrl.add(r);
          return; // avoid network in tests
        }
        if (_rerouteInFlight) {
          _rerouteCtrl.add(r);
          return;
        }
        _rerouteInFlight = true;
        try {
          final origin = _lastProcessedPosition;
          if (origin == null || _destination == null || _offlineCoordinator == null) {
            return;
          }
          final res = await _offlineCoordinator!.getRoute(
            origin: origin,
            destination: _destination!,
            isDistanceMode: _alarmMode == 'distance',
            threshold: _alarmValue ?? 0,
            transitMode: _transitMode,
            forceRefresh: false,
          );
          registerRouteFromDirections(
            directions: res.directions,
            origin: origin,
            destination: _destination!,
            transitMode: _transitMode,
            destinationName: _destinationName,
          );
          try { AppLogger.I.info('REROUTE_DECISION', domain: 'reroute', context: {
            'phase': 'applied',
            'source': res.source,
            'latencyMs': DateTime.now().difference(startTs).inMilliseconds,
          }); } catch (_) {}
        } catch (e) {
          try { AppLogger.I.warn('REROUTE_DECISION', domain: 'reroute', context: {
            'phase': 'error',
            'error': e.toString(),
          }); } catch (_) {}
        } finally {
          _rerouteInFlight = false;
        }
      }
      _rerouteCtrl.add(r);
    });
  }

  // Convenience: register from a Directions response
  void registerRouteFromDirections({
    required Map<String, dynamic> directions,
    required LatLng origin,
    required LatLng destination,
    required bool transitMode,
    String? destinationName,
  }) {
  final mode = transitMode ? 'transit' : 'driving';
    _transitMode = transitMode;
    _origin = origin;
    final key = RouteCache.makeKey(origin: origin, destination: destination, mode: mode, transitVariant: transitMode ? 'rail' : null);
    // Best-effort update of persisted session so cold-start resume knows transit context for segmented polyline rehydration
    () async {
      try {
        final file = await TrackingSessionStateFile.load();
        if (file != null) {
          file['transitMode'] = _transitMode;
          await TrackingSessionStateFile.save(file);
          print('GW_ARES_ST_UPDATE transitMode=$_transitMode');
        }
      } catch (e) { print('GW_ARES_ST_UPDATE_FAIL $e'); }
    }();
  // Extract polyline points
  List<LatLng> points = [];
    try {
      final route = (directions['routes'] as List).first as Map<String, dynamic>;
      final scp = route['simplified_polyline'] as String?;
      if (scp != null) {
        points = PolylineSimplifier.decompressPolyline(scp);
      } else if (route['overview_polyline'] != null && route['overview_polyline']['points'] != null) {
        points = decodePolyline(route['overview_polyline']['points'] as String);
      }
    } catch (_) {}
    // Build step bounds and stops
    try {
      final m = TransferUtils.buildStepBoundariesAndStops(directions);
      _stepBoundsMeters = m.bounds;
      _stepStopsCumulative = m.stops;
    } catch (_) {
      _stepBoundsMeters = const [];
      _stepStopsCumulative = const [];
    }
    // Fallback to straight line between origin/destination if no points decoded
    if (points.isEmpty) {
      points = [origin, destination];
    }
    // Build event boundaries and keep in memory
    try {
      _routeEvents = TransferUtils.buildRouteEvents(directions);
    } catch (_) {
      _routeEvents = const [];
    }
    // Compute first transit boarding meters and location for pre-boarding alert
    try {
  LatLng? boarding;
      final routes = (directions['routes'] as List?) ?? const [];
      if (routes.isNotEmpty) {
        final route = routes.first as Map<String, dynamic>;
        final legs = (route['legs'] as List?) ?? const [];
        outer:
        for (final leg in legs) {
          final steps = (leg['steps'] as List?) ?? const [];
          for (final s in steps) {
            final step = s as Map<String, dynamic>;
            // read-only
            if (step['travel_mode'] == 'TRANSIT') {
              // Try departure_stop location
              try {
                final dep = (step['transit_details'] as Map<String, dynamic>?)?['departure_stop'] as Map<String, dynamic>?;
                final loc = dep != null ? dep['location'] as Map<String, dynamic>? : null;
                if (loc != null) {
                  final lat = (loc['lat'] as num?)?.toDouble();
                  final lng = (loc['lng'] as num?)?.toDouble();
                  if (lat != null && lng != null) {
                    boarding = LatLng(lat, lng);
                  }
                }
              } catch (_) {}
              // Fallback to first point of step polyline
              if (boarding == null) {
                try {
                  final pts = decodePolyline((step['polyline'] as Map<String, dynamic>)['points'] as String);
                  if (pts.isNotEmpty) boarding = pts.first;
                } catch (_) {}
              }
              break outer;
            }
            // ignore step distance here
          }
        }
      }
      _firstTransitBoarding = boarding;
      dev.log('Computed first transit boarding: $_firstTransitBoarding', name: 'TrackingService');
      _preBoardingAlertFired = false;
    } catch (_) {
      _firstTransitBoarding = null;
      _preBoardingAlertFired = false;
    }
    registerRoute(
      key: key,
      mode: mode,
      destinationName: destinationName ?? 'Destination',
      points: points,
    );
    _logStopsIntegrityIfNeeded();
    _maybeEmitSessionCommit(routeKey: key, directions: directions);
  }
}


Future<void> startLocationStream(ServiceInstance service) async {
  if (TrackingService.isTestMode) {
    dev.log('TEST-PIPELINE: startLocationStream invoked (existingSub=${_positionSubscription!=null})', name: 'TrackingService');
  }
  if (_positionSubscription != null) {
    await _positionSubscription!.cancel();
  }
  // In test mode, bypass validator to preserve legacy test expectations (counts, timing)
  if (TrackingService.isTestMode) {
    _sampleValidator = _BypassSampleValidator();
  }
  // Ensure idle scaler exists before any samples to allow consistent factory injection in tests
  _idleScaler ??= (TrackingService.testIdleScalerFactory != null
      ? TrackingService.testIdleScalerFactory!()
      : IdlePowerScaler());
  int batteryLevel = 100;
  if (!TrackingService.isTestMode) {
    final Battery battery = Battery();
    batteryLevel = await battery.batteryLevel;
  }
  // Select power tier
  final policy = TrackingService.isTestMode
      ? PowerPolicy.testing()
      : PowerPolicyManager.forBatteryLevel(batteryLevel);
  // Apply gps dropout and reroute cooldown based on policy
  gpsDropoutBuffer = policy.gpsDropoutBuffer;
  if (_reroutePolicy != null && !TrackingService.isTestMode) {
    try {
      _reroutePolicy!.setCooldown(policy.rerouteCooldown);
    } catch (_) {}
  }
  
  LocationSettings settings = LocationSettings(
    accuracy: policy.accuracy,
    distanceFilter: policy.distanceFilterMeters,
  );

  Stream<Position> stream;
  if (_useInjectedPositions && _injectedCtrl != null) {
    stream = _injectedCtrl!.stream;
  } else {
    stream = testGpsStream ?? Geolocator.getPositionStream(locationSettings: settings);
  }
  
  _positionSubscription = stream.listen((Position position) {
    // Guard: ignore any late samples after stopTracking() toggled trackingActive false.
    if (!TrackingService.trackingActive) {
      if (TrackingService.isTestMode) {
        dev.log('TEST-PIPELINE: sample ignored post-stopTracking', name: 'TrackingService');
      }
      return;
    }
    if (TrackingService.isTestMode) {
      dev.log('TEST-PIPELINE: raw sample lat=${position.latitude} lng=${position.longitude}', name: 'TrackingService');
    }
    if (TrackingService.isTestMode) {
      dev.log('TEST-PIPELINE: received position lat=${position.latitude} lng=${position.longitude}', name: 'TrackingService');
    }
    final swPipeline = Stopwatch()..start();
    final nowTs = DateTime.now();
    _lastGpsUpdate = nowTs;
    // Validate sample first
    final valRes = _sampleValidator.validate(position, nowTs);
    if (!valRes.accepted) {
      if (TrackingService.isTestMode) {
        dev.log('TEST-PIPELINE: sample rejected by validator', name: 'TrackingService');
      }
      return; // Drop invalid sample quietly
    }
    if (TrackingService.isTestMode) {
      dev.log('TEST-PIPELINE: sample accepted', name: 'TrackingService');
    }
    _lastProcessedPosition = LatLng(position.latitude, position.longitude);
    // Update smoothed heading early so downstream (deviation / ETA if needed) can use it later.
    try {
      if (position.heading.isFinite) {
  _smoothedHeadingDeg = _headingSmoother.update(position.heading, nowTs, speedMps: position.speed);
        AppMetrics.I.inc('heading_samples');
      }
    } catch (_) {}
    // Track movement distance since start for time-alarm eligibility
    try {
      if (_startedAt == null) {
        _startedAt = DateTime.now();
      }
      if (_startPosition == null) {
        _startPosition = _lastProcessedPosition;
      }
      if (_startPosition != null && _lastProcessedPosition != null) {
        final d = Geolocator.distanceBetween(
          _startPosition!.latitude,
          _startPosition!.longitude,
          _lastProcessedPosition!.latitude,
          _lastProcessedPosition!.longitude,
        );
        _distanceTravelledMeters = d;
      }
    } catch (_) {}

    if (_fusionActive) {
      _sensorFusionManager?.stopFusion();
      _fusionActive = false;
    }

    // Modular ETA engine integration (mirrors legacy smoothing semantics)
    if (_destination != null) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _destination!.latitude,
        _destination!.longitude,
      );
      _movementClassifier.add(position.speed);
      // Speed mode change detection & logging
      final curMode = _movementClassifier.mode;
      if (TrackingService._lastMovementModeLogged == null) {
        TrackingService._lastMovementModeLogged = curMode;
        try { AppLogger.I.info('SPEED_MODE_CHANGE', domain: 'movement', context: {
          'mode': curMode,
          'initial': true,
          'ts': DateTime.now().toIso8601String(),
        }); } catch (_) {}
      } else if (TrackingService._lastMovementModeLogged != curMode) {
        final prev = TrackingService._lastMovementModeLogged;
        TrackingService._lastMovementModeLogged = curMode;
        try { AppLogger.I.info('SPEED_MODE_CHANGE', domain: 'movement', context: {
          'from': prev,
          'to': curMode,
          'ts': DateTime.now().toIso8601String(),
        }); } catch (_) {}
      }
      final repSpeed = _movementClassifier.representativeSpeed();
      _lastEtaResult = _etaEngine.update(
        distanceMeters: distance,
        representativeSpeedMps: repSpeed,
        movementMode: _movementClassifier.mode,
        gpsReliable: position.accuracy.isFinite && position.accuracy <= 50,
        onRoute: true, // route blending TODO
        isTestMode: TrackingService.isTestMode,
      );
      _smoothedETA = _lastEtaResult!.etaSeconds; // keep legacy field updated
      final thresholds = ThresholdsProvider.current;
      if (position.speed.isFinite && position.speed >= thresholds.gpsNoiseFloorMps) {
        _etaSamples = _etaEngine.etaSamples; // sync with engine sample count
      }
      if (TrackingService.isTestMode) {
        final sinceStart = _startedAt != null ? DateTime.now().difference(_startedAt!) : Duration.zero;
        AppLogger.I.debug('EtaEngine', domain: 'test', context: {
          'distTravelledM': _distanceTravelledMeters.toStringAsFixed(1),
          'etaSamples': _etaSamples.toString(),
          'etaSec': _smoothedETA?.toStringAsFixed(1),
          'sinceStartSec': sinceStart.inSeconds.toString(),
          'eligible': _timeAlarmEligible.toString(),
          'mode': _movementClassifier.mode,
          'repSpeed': repSpeed.toStringAsFixed(2),
          'confidence': _lastEtaResult!.confidence.toStringAsFixed(2),
          'volatility': _lastEtaResult!.volatility.toStringAsFixed(2),
          'rapidHint': _lastEtaResult!.immediateEvaluationHint.toString(),
        });
      }
      // Transfer alerts scheduling/firing (lightweight each update)
      if (_routeEvents.isNotEmpty && _lastActiveState != null) {
        final prog = _lastActiveState!.progressMeters;
        for (final ev in _routeEvents) {
          if (ev.type != 'transfer') continue;
          final distanceToEvent = ev.meters - prog;
            const scheduleWindow = 800.0; // meters
            if (distanceToEvent <= scheduleWindow && distanceToEvent > 0 && !TrackingService._transferAlertsScheduled.contains(ev.meters)) {
              TrackingService._transferAlertsScheduled.add(ev.meters);
              try { AppLogger.I.info('TRANSFER_ALERT', domain: 'transfer', context: {
                'eventMeters': ev.meters,
                'label': ev.label,
                'state': 'scheduled',
                'distanceToEvent': distanceToEvent,
              }); } catch (_) {}
            }
            if (distanceToEvent <= 0 && TrackingService._transferAlertsScheduled.contains(ev.meters) && !TrackingService._transferAlertsFired.contains(ev.meters)) {
              TrackingService._transferAlertsFired.add(ev.meters);
              try { AppLogger.I.info('TRANSFER_ALERT', domain: 'transfer', context: {
                'eventMeters': ev.meters,
                'label': ev.label,
                'state': 'fire',
              }); } catch (_) {}
            }
        }
      }
    }

    // Ingest into active route manager and deviation pipeline if present
    _lastSpeedMps = position.speed;
    if (_activeManager != null) {
      final raw = LatLng(position.latitude, position.longitude);
      _activeManager!.ingestPosition(raw);
    }

    // Dual‑run orchestrator feed (shadow mode)
    try {
      if (_orchestrator != null) {
        final sample = LocationSample(
          lat: position.latitude,
          lng: position.longitude,
            speedMps: position.speed,
            timestamp: DateTime.now(),
            accuracy: position.accuracy,
            heading: position.heading,
            altitude: position.altitude,
        );
        // Feed into orchestrator (shadow evaluation). Any result events handled via subscription.
        try {
          final snapped = _currentSnappedPositionForOrchestrator(position);
          _orchestrator!.update(sample: sample, snapped: snapped);
        } catch (_) {}
      }
    } catch (_) {}

    // Feed sample into idle power scaler (was previously missing, preventing idle transitions in tests)
    try {
      _idleScaler?.addSample(
        lat: position.latitude,
        lng: position.longitude,
        speedMps: position.speed,
        ts: nowTs,
      );
      if (TrackingService.isTestMode) {
        dev.log('TEST-PIPELINE: idleScaler feed isIdle=${_idleScaler?.isIdle}', name: 'TrackingService');
      }
    } catch (_) {}

    final mode = _idleScaler!.isIdle ? 'idle' : 'active';
    if (mode != _latestPowerMode) {
      _latestPowerMode = mode;
      EventBus().emit(PowerModeChangedEvent(mode));
    }

    // Evaluate time-alarm eligibility on each update first (respecting test overrides)
    try {
      if (_alarmMode == 'time' && !_timeAlarmEligible) {
        final thresholds = ThresholdsProvider.current;
        final sinceStart = _startedAt != null ? DateTime.now().difference(_startedAt!) : Duration.zero;
        final minDist = TrackingService.testTimeAlarmMinDistanceMeters ?? thresholds.minDistanceSinceStartMeters;
        final minSamples = TrackingService.testTimeAlarmMinSamples ?? thresholds.minEtaSamples;
        final effective = _effectiveMinSinceStart ?? (TrackingService.timeAlarmMinSinceStart != const Duration(seconds: 30)
            ? TrackingService.timeAlarmMinSinceStart
            : thresholds.minSinceStart);
        if (TrackingService.isTestMode) {
          dev.log('TimeEligibility(live) dist=${_distanceTravelledMeters.toStringAsFixed(1)}>=${minDist.toStringAsFixed(1)} samples=$_etaSamples>=$minSamples since=${sinceStart.inMilliseconds}ms>=${effective.inMilliseconds}ms', name: 'TrackingService');
        }
        if (_distanceTravelledMeters >= minDist && _etaSamples >= minSamples && sinceStart >= effective) {
          _timeAlarmEligible = true;
          dev.log('Time alarm is now eligible (live update)', name: 'TrackingService');
        }
      }
    } catch (_) {}

    // --- ADAPTIVE ALARM EVALUATION SCHEDULING ---
    try {
      double? remainingDistance;
      if (_destination != null) {
        remainingDistance = Geolocator.distanceBetween(position.latitude, position.longitude, _destination!.latitude, _destination!.longitude);
      }
      final desired = _computeDesiredAlarmEvalInterval(
        etaSeconds: _alarmMode == 'time' ? _smoothedETA : null,
        distanceMeters: _alarmMode == 'distance' ? remainingDistance : null,
      );
      _lastDesiredEvalInterval = desired; // track for diagnostics

      bool rapidEtaDrop = _lastEtaResult?.immediateEvaluationHint ?? false;

      final now = DateTime.now();
      final due = _lastAlarmEvalAt == null || now.difference(_lastAlarmEvalAt!) >= desired;
      _logEvalInterval(
        interval: desired,
        remainingMeters: remainingDistance,
        etaSeconds: _smoothedETA,
        remainingStops: (_alarmMode == 'stops' && _stepStopsCumulative.isNotEmpty) ? (_stepStopsCumulative.last) : null,
        confidence: _lastEtaResult?.confidence,
        volatility: _lastEtaResult?.volatility,
        immediateHint: rapidEtaDrop,
      );
      if (rapidEtaDrop || due) {
        if (_evalInProgress) {
          _pendingEval = true;
        } else {
          _evalInProgress = true;
          _lastAlarmEvalAt = now;
          final swEval = Stopwatch()..start();
          try {
            _checkAndTriggerAlarm(position, service);
          } finally {
            swEval.stop();
            core_metrics.MetricsRegistry().observe('alarm.eval.ms', swEval.elapsedMilliseconds.toDouble());
            core_metrics.MetricsRegistry().inc('alarm.eval.count');
            AppMetrics.I.observeDuration('alarm_eval', swEval.elapsed);
            AppMetrics.I.inc('alarm_eval_runs');
            _evalInProgress = false;
            if (_pendingEval) {
              _pendingEval = false;
              Future.microtask(() {
                final swEval2 = Stopwatch()..start();
                try { _checkAndTriggerAlarm(position, service); } finally {
                  swEval2.stop();
                  core_metrics.MetricsRegistry().observe('alarm.eval.ms', swEval2.elapsedMilliseconds.toDouble());
                  core_metrics.MetricsRegistry().inc('alarm.eval.count');
                  try { MetricsRegistry.I.counter('alarm.eval.count').inc(); } catch (_) {}
                  AppMetrics.I.observeDuration('alarm_eval', swEval2.elapsed);
                  AppMetrics.I.inc('alarm_eval_runs');
                }
              });
            }
          }
        }
      }
    } catch (_) {}

    // Progress instrumentation sample
    try { _logProgressSample(position); } catch (_) {}
    service.invoke("updateLocation", {
      "latitude": position.latitude,
      "longitude": position.longitude,
      "eta": _smoothedETA,
  "heading": _smoothedHeadingDeg,
    });
    // Expose adaptive scheduling interval for diagnostics (ignored in tests)
    try { core_metrics.MetricsRegistry().gauge('alarm.eval.desired_interval_ms', _lastDesiredEvalInterval.inMilliseconds.toDouble()); } catch (_) {}
    swPipeline.stop();
    core_metrics.MetricsRegistry().observe('location.pipeline.ms', swPipeline.elapsedMilliseconds.toDouble());
    core_metrics.MetricsRegistry().inc('location.updates');
    try { MetricsRegistry.I.counter('location.updates').inc(); } catch (_) {}
    if (TrackingService.isTestMode) {
      // Auxiliary counter for diagnostics (can be removed after stabilization)
      try { core_metrics.MetricsRegistry().inc('location.updates.test'); } catch (_) {}
      try { MetricsRegistry.I.counter('location.updates.test').inc(); } catch (_) {}
    }
    core_metrics.MetricsRegistry().gauge('eta.seconds', _smoothedETA ?? -1);
  if (_smoothedHeadingDeg != null) {
      // Use legacy registry gauge name convention by reusing metrics registry counters
      try { core_metrics.MetricsRegistry().gauge('heading.deg', _smoothedHeadingDeg!); } catch (_) {}
    }
    AppMetrics.I.observeDuration('location_pipeline', swPipeline.elapsed);
    AppMetrics.I.inc('location_updates');
  });
  // Start GPS dropout checker to enable sensor fusion when GPS is silent.
  _gpsCheckTimer?.cancel();
  final Duration checkPeriod = TrackingService.isTestMode ? policy.notificationTick : policy.notificationTick;
  _gpsCheckTimer = Timer.periodic(checkPeriod, (_) {
    final last = _lastGpsUpdate;
    if (last == null) return;
    final silentFor = DateTime.now().difference(last);
    if (silentFor >= gpsDropoutBuffer) {
      if (!_fusionActive && _lastProcessedPosition != null) {
        _sensorFusionManager = SensorFusionManager(
          initialPosition: _lastProcessedPosition!,
          accelerometerStream: testAccelerometerStream,
        );
        _sensorFusionManager!.startFusion();
        _fusionActive = true;
      }
    }
    
    // Regularly force notification updates even without state changes
    _updateNotification(service);
    // Evaluate time-alarm eligibility periodically
    try {
      if (_alarmMode == 'time' && !_timeAlarmEligible) {
        final thresholds = ThresholdsProvider.current;
        final sinceStart = _startedAt != null ? DateTime.now().difference(_startedAt!) : Duration.zero;
        final minDist = TrackingService.testTimeAlarmMinDistanceMeters ?? thresholds.minDistanceSinceStartMeters;
        final minSamples = TrackingService.testTimeAlarmMinSamples ?? thresholds.minEtaSamples;
        // Respect explicit test override for minSinceStart via static field if changed from default 30s
        final effective = _effectiveMinSinceStart ?? (TrackingService.timeAlarmMinSinceStart != const Duration(seconds: 30)
            ? TrackingService.timeAlarmMinSinceStart
            : thresholds.minSinceStart);
        if (TrackingService.isTestMode) {
          dev.log('TimeEligibility(timer) dist=${_distanceTravelledMeters.toStringAsFixed(1)}>=${minDist.toStringAsFixed(1)} samples=$_etaSamples>=$minSamples since=${sinceStart.inMilliseconds}ms>=${effective.inMilliseconds}ms', name: 'TrackingService');
        }
        if (_distanceTravelledMeters >= minDist && _etaSamples >= minSamples && sinceStart >= effective) {
          _timeAlarmEligible = true;
          dev.log('Time alarm is now eligible', name: 'TrackingService');
        }
      }
    } catch (_) {}
  });
}

// Helper method to update notification based on current state
void _updateNotification(ServiceInstance service) {
  try {
    if (TrackingService.isTestMode || _destination == null) return;
    
    // Get latest state from active manager if available
    if (_activeManager != null && _registry.entries.isNotEmpty) {
      // We can't directly access the active key from the manager,
      // but we have some options to find it:
      RouteEntry? entry;
      
      try {
        // Find the most recently used route or one with the best progress data
        if (_registry.entries.isNotEmpty) {
          RouteEntry? bestEntry;
          for (final e in _registry.entries) {
            if (e.lastProgressMeters != null) {
              if (bestEntry == null || e.lastUsed.isAfter(bestEntry.lastUsed)) {
                bestEntry = e;
              }
            }
          }
          
          // If we found a route with progress data, use it
          if (bestEntry != null) {
            entry = bestEntry;
          } else {
            // Otherwise use the first one
            entry = _registry.entries.first;
          }
        }
      } catch (_) {
        // Fallback to first entry if any error occurs
        if (_registry.entries.isNotEmpty) {
          entry = _registry.entries.first;
        }
      }
      
      if (entry != null) {
        final total = entry.lengthMeters;
        final progressMeters = entry.lastProgressMeters ?? 0.0;
        final progress = total > 0 ? (progressMeters / total).clamp(0.0, 1.0) : 0.0;
        final remainingMeters = total - progressMeters;
        
        // Create progress notification
        final progressPercent = (progress * 100).clamp(0.0, 100.0).toStringAsFixed(1);
        final remainingKm = (remainingMeters / 1000.0).toStringAsFixed(1);
        
        dev.log('Forced notification update: $progressPercent% | remaining $remainingKm km', 
               name: 'TrackingService');
        
        NotificationService().showJourneyProgress(
          title: _destinationName != null ? 'Journey to $_destinationName' : 'GeoWake journey',
          subtitle: 'Remaining: $remainingKm km',
          progress0to1: progress,
        );
        
        return;
      }
    }
    
    // Fallback if no active route: use straight-line distance
    if (_lastProcessedPosition != null && _destination != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _lastProcessedPosition!.latitude,
        _lastProcessedPosition!.longitude,
        _destination!.latitude,
        _destination!.longitude,
      );
      
      // Create a simple progress notification
      final remainingKm = (distanceInMeters / 1000.0).toStringAsFixed(1);
      dev.log('Simple notification update: remaining $remainingKm km', name: 'TrackingService');
      
      NotificationService().showJourneyProgress(
        title: _destinationName != null ? 'Journey to $_destinationName' : 'GeoWake journey',
        subtitle: 'Remaining: $remainingKm km',
        progress0to1: 0.0, // We don't know total journey distance in this case
      );
    }
  } catch (e) {
    dev.log('Error updating notification: $e', name: 'TrackingService');
  }
}

// No top-level testing getters; use instance getters on TrackingService.
