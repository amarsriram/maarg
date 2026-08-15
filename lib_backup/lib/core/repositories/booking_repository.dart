import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/booking_model.dart';
import '../models/load_model.dart';
import '../utils/logger_service.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  return BookingRepository(FirebaseFirestore.instance, logger);
});

// Stream of bookings for a specific load
final loadBookingsProvider = StreamProvider.autoDispose.family<List<BookingModel>, String>((ref, loadId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getLoadBookings(loadId).handleError((e) {
    debugPrint('STREAM ERROR: $e');
  });
});

// Stream of the active booking for a specific truck owner
final truckOwnerActiveBookingProvider = StreamProvider.autoDispose.family<BookingModel?, String>((ref, uid) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getTruckOwnerActiveBooking(uid).handleError((e) {
    debugPrint('STREAM ERROR: $e');
  });
});

/// Streams the truck owner's booking for a specific load.
/// Used to reactively update the "Request Load" button state.
/// Key format: "truckOwnerUid|loadId"
final truckOwnerBookingForLoadProvider = StreamProvider.autoDispose.family<BookingModel?, String>((ref, key) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final parts = key.split('|');
  if (parts.length != 2) return Stream.value(null);
  final truckOwnerUid = parts[0];
  final loadId = parts[1];
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getTruckOwnerBookingForLoad(truckOwnerUid, loadId).handleError((e) {
    debugPrint('STREAM ERROR: $e');
  });
});

class BookingRepository {
  final FirebaseFirestore _firestore;
  final LoggerService _logger;

  BookingRepository(this._firestore, this._logger);

  CollectionReference get _bookings => _firestore.collection('bookings');

  Future<void> createBooking(BookingModel booking) async {
    _logger.debug('Attempting to create booking for load ${booking.loadId}', tag: 'BookingRepository');
    // Prevent duplicate bookings from the same truck owner for the same load
    final query = await _bookings
        .where('loadId', isEqualTo: booking.loadId)
        .where('truckOwnerUid', isEqualTo: booking.truckOwnerUid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      _logger.warning('Duplicate booking prevented for load ${booking.loadId}', tag: 'BookingRepository');
      throw Exception('You have already requested this load.');
    }

    await _bookings.doc(booking.bookingId).set(booking.toJson());
    _logger.info('Booking created successfully: ${booking.bookingId}', tag: 'BookingRepository');
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    _logger.debug('Updating booking $bookingId status to $newStatus', tag: 'BookingRepository');
    await _bookings.doc(bookingId).update({'status': newStatus});
  }

  Future<void> acceptBookingBatch(BookingModel booking) async {
    _logger.transaction('acceptBookingBatch', 'STARTED');
    try {
      final batch = _firestore.batch();
      
      // Update booking status to accepted
      _logger.debug('UPDATING BOOKING...', tag: 'acceptBookingBatch');
      final bookingRef = _bookings.doc(booking.bookingId);
      batch.update(bookingRef, {'status': 'accepted'});

      // Update load with assignment and booked status
      _logger.debug('UPDATING LOAD...', tag: 'acceptBookingBatch');
      final loadRef = _firestore.collection('loads').doc(booking.loadId);
      batch.update(loadRef, {
        'status': 'active',
        'assignedTruckOwnerUid': booking.truckOwnerUid,
        'assignedTruckOwnerName': booking.truckOwnerName,
      });

      _logger.debug('CREATING TRIP...', tag: 'acceptBookingBatch');
      final tripId = booking.loadId;
      final tripRef = _firestore.collection('trips').doc(tripId);
      batch.set(tripRef, {
        'tripId': tripId,
        'loadId': booking.loadId,
        'providerUid': booking.providerUid,
        'truckOwnerUid': booking.truckOwnerUid,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.debug('TRIP CREATED: $tripId', tag: 'acceptBookingBatch');

      await batch.commit();
      _logger.transaction('acceptBookingBatch', 'SUCCESS');
    } catch (e, stack) {
      _logger.error('Failed to accept booking', tag: 'BookingRepository', error: e, stackTrace: stack);
      _logger.transaction('acceptBookingBatch', 'FAILED');
      rethrow;
    }
  }

  Stream<List<BookingModel>> getLoadBookings(String loadId) {
    return _bookings
        .where('loadId', isEqualTo: loadId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<BookingModel?> getTruckOwnerActiveBooking(String truckOwnerUid) {
    // Assuming 'accepted' means an active trip in progress.
    return _bookings
        .where('truckOwnerUid', isEqualTo: truckOwnerUid)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return BookingModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  /// Streams the truck owner's booking (any status) for a specific load.
  /// Returns null if no booking exists from this truck owner for this load.
  Stream<BookingModel?> getTruckOwnerBookingForLoad(String truckOwnerUid, String loadId) {
    return _bookings
        .where('truckOwnerUid', isEqualTo: truckOwnerUid)
        .where('loadId', isEqualTo: loadId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return BookingModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    });
  }
}
