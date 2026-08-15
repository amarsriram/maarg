import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../find_truck/domain/truck_model.dart';

/// Manage list of available empty return routes.
class RouteRepository extends StateNotifier<List<TruckRoute>> {
  RouteRepository() : super(_initialMockRoutes);

  static final List<TruckRoute> _initialMockRoutes = [
    TruckRoute(
      id: 'route-1',
      ownerId: 'owner-1',
      ownerName: 'Sunil Singh',
      companyName: 'Shergill Roadways',
      source: 'Mumbai',
      destination: 'Ahmedabad',
      date: DateTime.now().add(const Duration(days: 2)),
      truckType: 'Container 20ft',
      capacity: 15.0,
      price: 24000.0,
      vehicleNumber: 'MH-04-GP-8832',
      contactNumber: '+91 91234 56789',
    ),
    TruckRoute(
      id: 'route-2',
      ownerId: 'owner-2',
      ownerName: 'Satish Yadav',
      companyName: 'Yadav Freight carriers',
      source: 'Delhi',
      destination: 'Jaipur',
      date: DateTime.now().add(const Duration(days: 1)),
      truckType: 'Open Body 19ft',
      capacity: 10.0,
      price: 11500.0,
      vehicleNumber: 'DL-01-AB-1299',
      contactNumber: '+91 98321 45670',
    ),
    TruckRoute(
      id: 'route-3',
      ownerId: 'owner-3',
      ownerName: 'Mani Ratnam',
      companyName: 'Southern Star Logistics',
      source: 'Bengaluru',
      destination: 'Chennai',
      date: DateTime.now().add(const Duration(days: 3)),
      truckType: 'Flatbed Trailer 40ft',
      capacity: 25.0,
      price: 31000.0,
      vehicleNumber: 'KA-51-MM-4491',
      contactNumber: '+91 99000 88888',
    ),
    TruckRoute(
      id: 'route-4',
      ownerId: 'owner-1',
      ownerName: 'Sunil Singh',
      companyName: 'Shergill Roadways',
      source: 'Pune',
      destination: 'Mumbai',
      date: DateTime.now().add(const Duration(days: 4)),
      truckType: 'Chauras (Closed container)',
      capacity: 8.0,
      price: 6500.0,
      vehicleNumber: 'MH-12-QQ-4321',
      contactNumber: '+91 91234 56789',
    ),
    TruckRoute(
      id: 'route-5',
      ownerId: 'owner-4',
      ownerName: 'Karthik Reddy',
      companyName: 'Deccan Express',
      source: 'Hyderabad',
      destination: 'Bengaluru',
      date: DateTime.now().add(const Duration(days: 2)),
      truckType: 'Container 32ft MXL',
      capacity: 20.0,
      price: 28500.0,
      vehicleNumber: 'TS-09-UB-8765',
      contactNumber: '+91 90001 20002',
    ),
  ];

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
