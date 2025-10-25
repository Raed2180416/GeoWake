import 'dart:async';
import 'package:geowake2/services/event_bus.dart';

class RerouteDecision {
  final bool shouldReroute;
  final DateTime at;
  const RerouteDecision(this.shouldReroute, this.at);
}

class ReroutePolicy {
  Duration _cooldown;
  bool _online;
  DateTime? _lastRerouteAt;

  final _decisionCtrl = StreamController<RerouteDecision>.broadcast();
  Stream<RerouteDecision> get stream => _decisionCtrl.stream;

  ReroutePolicy({Duration cooldown = const Duration(seconds: 20), bool initialOnline = true})
      : _cooldown = cooldown,
        _online = initialOnline;

  Duration get cooldown => _cooldown;
  void setCooldown(Duration newCooldown) {
    _cooldown = newCooldown;
  }

  void setOnline(bool online) {
    _online = online;
  }

  bool _cooldownActive(DateTime now) =>
    _lastRerouteAt != null && now.difference(_lastRerouteAt!) < _cooldown;

  void onSustainedDeviation({required DateTime at}) {
    final now = at;
    if (!_online) {
      _decisionCtrl.add(RerouteDecision(false, now));
      EventBus().emit(RerouteDecisionEvent('offline_cooldown_or_offline'));
      return;
    }
    if (_cooldownActive(now)) {
      _decisionCtrl.add(RerouteDecision(false, now));
      EventBus().emit(RerouteDecisionEvent('cooldown_active'));
      return;
    }
    _lastRerouteAt = now;
    _decisionCtrl.add(RerouteDecision(true, now));
    EventBus().emit(RerouteDecisionEvent('sustained_deviation'));
  }

  void dispose() {
    _decisionCtrl.close();
  }
}
