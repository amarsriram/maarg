import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../find_truck/domain/truck_model.dart';

/// Manage list of available empty return routes.
class RouteRepository extends StateNotifier<List<TruckRoute>> {
  RouteRepository() : super(_initialMockRoutes);

  static final List<TruckRoute> _initialMockRoutes = [];

  Future<void> addRoute(TruckRoute route) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate remote insert
    state = [route, ...state];
  }

  Future<void> updateRouteStatus(String routeId, TruckStatus newStatus) async {
    state = state.map((r) {
      if (r.id == routeId) {
        return r.copyWith(status: newStatus);
      }
      return r;
    }).toList();
  }
}

// Global Provider for Route List State
final routeRepositoryProvider = StateNotifierProvider<RouteRepository, List<TruckRoute>>((ref) {
  return RouteRepository();
});
