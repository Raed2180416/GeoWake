// lib/services/route_queue.dart
import 'package:geowake2/models/route_models.dart';

/// Singleton class to manage a queue of routes.
class RouteQueue {
  static final RouteQueue instance = RouteQueue._internal();
  final int maxSize = 8;
  final List<RouteModel> _routes = [];
  int activeRouteIndex = 0;

  RouteQueue._internal();

  /// Adds a new route to the queue. If the queue is full, the oldest route is removed.
  void addRoute(RouteModel route) {
    if (_routes.length >= maxSize) {
      _routes.removeAt(0);
      if (activeRouteIndex > 0) {
        activeRouteIndex--;
      }
    }
    _routes.add(route);
    // Set the new route as the active one.
    activeRouteIndex = _routes.length - 1;
    _setActiveFlags();
  }

  /// Returns the currently active route.
  RouteModel? getActiveRoute() {
    if (_routes.isEmpty) return null;
    return _routes[activeRouteIndex];
  }

  /// Sets the route at the given index as active.
  void setActiveRoute(int index) {
    if (index >= 0 && index < _routes.length) {
      activeRouteIndex = index;
      _setActiveFlags();
    }
  }

  /// Helper to update the isActive flag on all routes.
  void _setActiveFlags() {
    for (int i = 0; i < _routes.length; i++) {
      _routes[i].isActive = (i == activeRouteIndex);
    }
  }

  /// Returns an unmodifiable list of all routes.
  List<RouteModel> get routes => List.unmodifiable(_routes);
}
