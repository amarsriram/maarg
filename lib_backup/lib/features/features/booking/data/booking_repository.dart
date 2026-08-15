import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user_model.dart';
import '../../find_truck/domain/truck_model.dart';
import '../../post_route/data/route_repository.dart';
import '../domain/booking_model.dart';

class BookingRepository extends StateNotifier<List<Booking>> {
  final Ref _ref;

  BookingRepository(this._ref) : super(_initialMockBookings);

  static final List<Booking> _initialMockBookings = [
    Booking(
      id: 'book-1',
      truckRouteId: 'route-2',
      supplierId: 'supplier-user-id',
      supplierName: 'Sunil Mehta',
      supplierCompanyName: 'Ganga Cement Corp',
      companyName: 'Yadav Freight carriers',
      source: 'Delhi',
      destination: 'Jaipur',
      date: DateTime.now().add(const Duration(days: 1)),
      price: 11500.0,
      brokerCommission: 575.0, // 5%
      status: BookingStatus.confirmed,
      vehicleNumber: 'DL-01-AB-1299',
      bookingDate: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Booking(
      id: 'book-2',
      truckRouteId: 'route-3',
      supplierId: 'supplier-user-id',
      supplierName: 'Sunil Mehta',
      supplierCompanyName: 'Ganga Cement Corp',
      companyName: 'Southern Star Logistics',
      source: 'Bengaluru',
      destination: 'Chennai',
      date: DateTime.now().subtract(const Duration(days: 4)),
      price: 31000.0,
      brokerCommission: 1550.0, // 5%
      status: BookingStatus.completed,
      vehicleNumber: 'KA-51-MM-4491',
      bookingDate: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  Future<bool> createBooking(TruckRoute route, AppUser supplier) async {
    await Future.delayed(const Duration(milliseconds: 1500)); // Simulate network transaction

    final newBooking = Booking(
      id: 'book-${DateTime.now().millisecondsSinceEpoch}',
      truckRouteId: route.id,
      supplierId: supplier.id,
      supplierName: supplier.providerDisplayName,
      supplierCompanyName: supplier.companyName ?? 'Independent Supplier',
      companyName: route.companyName,
      source: route.source,
      destination: route.destination,
      date: route.date,
      price: route.price,
      brokerCommission: route.price * 0.05, // 5%
      status: BookingStatus.pending,
      vehicleNumber: route.vehicleNumber,
      bookingDate: DateTime.now(),
    );

    // Append booking to local in-memory state
    state = [newBooking, ...state];

    // Update the route status to booked
    await _ref.read(routeRepositoryProvider.notifier).updateRouteStatus(route.id, TruckStatus.booked);

    return true;
  }

  Future<void> updateBookingStatus(String bookingId, BookingStatus status) async {
    state = state.map((b) {
      if (b.id == bookingId) {
        return b.copyWith(status: status);
      }
      return b;
    }).toList();
  }
}

// Global Provider for Booking State
final bookingRepositoryProvider = StateNotifierProvider<BookingRepository, List<Booking>>((ref) {
  return BookingRepository(ref);
});
