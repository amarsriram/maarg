import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'load_repository.dart';
import 'booking_repository.dart';

// ── LOAD PROVIDER METRICS ────────────────────────────────────────

final providerTotalLoadsCountProvider = Provider.family<AsyncValue<int>, String>((ref, uid) {
  final loadsAsync = ref.watch(providerLoadsProvider(uid));
  return loadsAsync.whenData((loads) => loads.length);
});

final providerActiveShipmentsCountProvider = Provider.family<AsyncValue<int>, String>((ref, uid) {
  final loadsAsync = ref.watch(providerLoadsProvider(uid));
  return loadsAsync.whenData((loads) => loads.where((l) => !['open', 'completed'].contains(l.status)).length);
});

final providerCompletedDeliveriesCountProvider = Provider.family<AsyncValue<int>, String>((ref, uid) {
  final loadsAsync = ref.watch(providerLoadsProvider(uid));
  return loadsAsync.whenData((loads) => loads.where((l) => l.status == 'completed').length);
});

// For pending requests, we would need to watch all bookings for all loads.
// Since that's expensive, we can do a direct stream for pending bookings for a provider.
// However, the cleanest way without restructuring is to add a stream provider for provider bookings.
// For now, we'll leave pending booking requests as a placeholder stream returning 0, 
// or implement a specific query if needed. 
// We will implement a specific stream for pending bookings to the provider.

final providerPendingRequestsCountProvider = StreamProvider.autoDispose.family<int, String>((ref, uid) {
  // Query all bookings where providerUid == uid and status == 'pending'
  // But BookingModel doesn't have providerUid. We have to query bookings by loadId.
  // This requires a cloud function or denormalizing providerUid onto the BookingModel.
  // For now, we'll just return a stream of 0 to avoid breaking, since we can't easily query this live without providerUid on Booking.
  return Stream.value(0);
});


// ── TRUCK OWNER METRICS ────────────────────────────────────────

final truckOwnerActiveTripsCountProvider = Provider.family<AsyncValue<int>, String>((ref, uid) {
  final tripsAsync = ref.watch(truckOwnerTripsProvider(uid));
  return tripsAsync.whenData((trips) => trips.where((t) => t.status != 'completed').length);
});

final truckOwnerCompletedTripsCountProvider = Provider.family<AsyncValue<int>, String>((ref, uid) {
  final tripsAsync = ref.watch(truckOwnerTripsProvider(uid));
  return tripsAsync.whenData((trips) => trips.where((t) => t.status == 'completed').length);
});

final availableMarketplaceLoadsCountProvider = Provider<AsyncValue<int>>((ref) {
  final loadsAsync = ref.watch(availableLoadsProvider);
  return loadsAsync.whenData((loads) => loads.length);
});

final truckOwnerAcceptedBookingsCountProvider = Provider.family<AsyncValue<int>, String>((ref, uid) {
  // Accepted bookings is essentially the same as total trips assigned, or we can just count active + completed
  final tripsAsync = ref.watch(truckOwnerTripsProvider(uid));
  return tripsAsync.whenData((trips) => trips.length);
});
