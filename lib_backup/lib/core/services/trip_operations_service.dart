import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/load_model.dart';
import '../models/booking_model.dart';
import '../models/trip_event_model.dart';
import '../models/notification_model.dart';
import '../models/trip_status.dart';
import '../../features/auth/domain/user_model.dart';

final tripOperationsServiceProvider = Provider<TripOperationsService>((ref) {
  return TripOperationsService(FirebaseFirestore.instance);
});

class TripOperationsService {
  final FirebaseFirestore _firestore;

  TripOperationsService(this._firestore);

  /// Accepts a booking using a Firestore TRANSACTION (atomic all-or-nothing).
  Future<void> acceptBooking(BookingModel booking, AppUser currentUser) async {
    debugPrint('ACCEPT BOOKING START: bookingId=${booking.bookingId}, loadId=${booking.loadId}');
    
    try {
      // Pre-fetch pending bookings to reject them atomically inside the transaction
      final pendingQuery = await _firestore
          .collection('bookings')
          .where('loadId', isEqualTo: booking.loadId)
          .where('status', isEqualTo: 'pending')
          .get(const GetOptions(source: Source.server));

      await _firestore.runTransaction((transaction) async {
        final loadRef = _firestore.collection('loads').doc(booking.loadId);
        final loadSnap = await transaction.get(loadRef);

        if (!loadSnap.exists) {
          throw Exception('Load document not found.');
        }

        final loadData = loadSnap.data()!;
        final currentStatusStr = loadData['status'] as String?;
        final currentStatus = TripStatusExtension.fromString(currentStatusStr);

        if (currentStatus != TripStatus.open) {
          throw Exception('Load is no longer open (current status: ${currentStatus.displayName}). Cannot accept.');
        }

        final bookingRef = _firestore.collection('bookings').doc(booking.bookingId);
        final bookingSnap = await transaction.get(bookingRef);

        if (!bookingSnap.exists) {
          throw Exception('Booking document not found.');
        }

        final bookingStatus = bookingSnap.data()!['status'] as String?;
        
        if (bookingStatus != 'pending') {
          throw Exception('Booking is no longer pending (current status: $bookingStatus).');
        }

        // Update booking status to accepted
        debugPrint('STEP 1 -> updating booking');
        try {
          transaction.update(bookingRef, {
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('FAILED AT STEP 1: $e');
          rethrow;
        }

        // Update load to assigned
        debugPrint('STEP 2 -> updating load');
        try {
          transaction.update(loadRef, {
            'status': TripStatus.assigned.name,
            'assignedTruckOwnerUid': booking.truckOwnerUid,
            'assignedTruckOwnerName': booking.truckOwnerName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('FAILED AT STEP 2: $e');
          rethrow;
        }

        // Create trip document
        debugPrint('STEP 3 -> creating trip');
        try {
          final tripId = booking.loadId;
          final tripRef = _firestore.collection('trips').doc(tripId);
          final tripData = {
            'tripId': tripId,
            'loadId': booking.loadId,
            'providerUid': currentUser.id, // Forcing current user ID to ensure rule match
            'truckOwnerUid': booking.truckOwnerUid,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          transaction.set(tripRef, tripData);
        } catch (e) {
          debugPrint('FAILED AT STEP 3: $e');
          rethrow;
        }

        // Create trip event
        debugPrint('STEP 4 -> creating trip event');
        try {
          final eventRef = _firestore.collection('tripEvents').doc();
          final event = TripEventModel(
            eventId: eventRef.id,
            tripId: booking.loadId,
            loadId: booking.loadId,
            eventType: 'booking_accepted',
            message: '${currentUser.displayName} accepted booking from ${booking.truckOwnerName}',
            actorUid: currentUser.id,
            actorName: currentUser.displayName,
            createdAt: DateTime.now(),
          );
          transaction.set(eventRef, event.toJson());
        } catch (e) {
          debugPrint('FAILED AT STEP 4: $e');
          rethrow;
        }

        // Send notification to truck owner
        debugPrint('STEP 5 -> creating notification');
        try {
          final notifRef = _firestore.collection('notifications').doc();
          final notif = NotificationModel(
            notificationId: notifRef.id,
            uid: booking.truckOwnerUid,
            title: 'Booking Accepted',
            message: 'Your booking request for Load #${booking.loadId.substring(0, 8).toUpperCase()} was accepted.',
            type: 'operational',
            createdAt: DateTime.now(),
          );
          transaction.set(notifRef, notif.toJson());
        } catch (e) {
          debugPrint('FAILED AT STEP 5: $e');
          rethrow;
        }

        // Reject other pending bookings atomically
        debugPrint('STEP 6 -> rejecting other pending bookings');
        for (final doc in pendingQuery.docs) {
          if (doc.id != booking.bookingId) {
            final otherBookingRef = _firestore.collection('bookings').doc(doc.id);
            // Read to ensure it hasn't changed (locks the document in the transaction)
            final snap = await transaction.get(otherBookingRef);
            if (snap.exists && snap.data()?['status'] == 'pending') {
              transaction.update(otherBookingRef, {
                'status': 'rejected',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              
              final rejectedUid = snap.data()?['truckOwnerUid'] as String?;
              if (rejectedUid != null) {
                final notifRef = _firestore.collection('notifications').doc();
                final notif = NotificationModel(
                  notificationId: notifRef.id,
                  uid: rejectedUid,
                  title: 'Booking Not Selected',
                  message: 'Another driver was selected for Load #${booking.loadId.substring(0, 8).toUpperCase()}.',
                  type: 'operational',
                  createdAt: DateTime.now(),
                );
                transaction.set(notifRef, notif.toJson());
              }
            }
          }
        }
        
        debugPrint('STEP 7 -> committing transaction');
      });

      debugPrint('ACCEPT BOOKING COMPLETE');
    } catch (e, stack) {
      debugPrint('ACCEPT BOOKING FAILED: $e');
      debugPrint('ACCEPT BOOKING STACK: $stack');
      rethrow;
    }
  }

  Future<void> rejectBooking(BookingModel booking, AppUser currentUser) async {
    try {
      final batch = _firestore.batch();
      final bookingRef = _firestore.collection('bookings').doc(booking.bookingId);
      batch.update(bookingRef, {
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final notifRef = _firestore.collection('notifications').doc();
      final notif = NotificationModel(
        notificationId: notifRef.id,
        uid: booking.truckOwnerUid,
        title: 'Booking Rejected',
        message: 'Your booking request for Load #${booking.loadId.substring(0, 8).toUpperCase()} was declined.',
        type: 'operational',
        createdAt: DateTime.now(),
      );
      batch.set(notifRef, notif.toJson());

      await batch.commit();
    } catch (e) {
      debugPrint('REJECT BOOKING FAILED: $e');
      rethrow;
    }
  }

  /// Requests a booking using a TRANSACTION to prevent duplicates.
  Future<void> requestBooking(LoadModel load, AppUser currentUser) async {
    debugPrint('REQUEST BOOKING START: loadId=${load.loadId}, truckOwner=${currentUser.id}');

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Verify load is still open
        final loadRef = _firestore.collection('loads').doc(load.loadId);
        final loadSnap = await transaction.get(loadRef);

        if (!loadSnap.exists) {
          throw Exception('Load document not found.');
        }

        final currentStatus = TripStatusExtension.fromString(loadSnap.data()!['status'] as String?);
        if (currentStatus != TripStatus.open) {
          throw Exception('This load is no longer available (current status: ${currentStatus.displayName}).');
        }

        // 2. Query existing bookings for this truck owner and load
        // NOTE: We can't query collections directly in a transaction reliably without limits,
        // so we check if they already have an active booking outside, or use a known document ID pattern.
        // Actually, let's use a deterministic ID for bookings to enforce uniqueness!
        // Deterministic ID: loadId_truckOwnerUid
        final bookingId = '${load.loadId}_${currentUser.id}';
        final bookingRef = _firestore.collection('bookings').doc(bookingId);
        
        final bookingSnap = await transaction.get(bookingRef);
        
        if (bookingSnap.exists) {
          final existingStatus = bookingSnap.data()!['status'] as String?;
          if (existingStatus == 'pending' || existingStatus == 'accepted') {
            throw Exception('You already have a $existingStatus booking for this load.');
          }
          // If rejected, we allow a retry by overwriting or updating. 
          // For simplicity, we overwrite.
        }

        final booking = BookingModel(
          bookingId: bookingRef.id,
          loadId: load.loadId,
          providerUid: load.providerUid,
          truckOwnerUid: currentUser.id,
          truckOwnerName: currentUser.displayName,
          pickupLocation: load.pickupLocation,
          dropLocation: load.dropLocation,
          budget: load.budget,
          status: 'pending',
          createdAt: DateTime.now(),
        );
        
        transaction.set(bookingRef, booking.toJson());

        final notifRef = _firestore.collection('notifications').doc();
        final notif = NotificationModel(
          notificationId: notifRef.id,
          uid: load.providerUid,
          title: 'New Booking Request',
          message: '${currentUser.displayName} requested to carry Load #${load.loadId.substring(0, 8).toUpperCase()}.',
          type: 'operational',
          createdAt: DateTime.now(),
        );
        transaction.set(notifRef, notif.toJson());
      });

      debugPrint('REQUEST BOOKING COMPLETE');
    } catch (e, stack) {
      debugPrint('REQUEST BOOKING FAILED: $e');
      debugPrint('REQUEST BOOKING STACK: $stack');
      rethrow;
    }
  }

  Future<void> advanceLoadStatus(LoadModel load, TripStatus nextStatus, AppUser currentUser) async {
    debugPrint('ADVANCE STATUS: loadId=${load.loadId}, nextStatus=${nextStatus.name}, actor=${currentUser.id}');

    try {
      final currentStatus = load.tripStatus;
      
      if (!currentStatus.canTransitionTo(nextStatus)) {
        throw Exception('Invalid state transition from ${currentStatus.name} to ${nextStatus.name}');
      }

      final batch = _firestore.batch();
      final loadRef = _firestore.collection('loads').doc(load.loadId);
      
      batch.update(loadRef, {
        'status': nextStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final eventRef = _firestore.collection('tripEvents').doc();
      final event = TripEventModel(
        eventId: eventRef.id,
        tripId: load.loadId,
        loadId: load.loadId,
        eventType: nextStatus.name,
        message: 'Status updated to ${nextStatus.displayName}',
        actorUid: currentUser.id,
        actorName: currentUser.displayName,
        createdAt: DateTime.now(),
      );
      batch.set(eventRef, event.toJson());

      final recipientUid = currentUser.id == load.providerUid ? load.assignedTruckOwnerUid : load.providerUid;
      if (recipientUid != null) {
        final notifRef = _firestore.collection('notifications').doc();
        final notif = NotificationModel(
          notificationId: notifRef.id,
          uid: recipientUid,
          title: 'Trip Status Update',
          message: 'Load #${load.loadId.substring(0, 8).toUpperCase()} is now ${nextStatus.displayName}.',
          type: 'operational',
          createdAt: DateTime.now(),
        );
        batch.set(notifRef, notif.toJson());
      }

      await batch.commit();
      debugPrint('ADVANCE STATUS COMPLETE: ${nextStatus.name}');
    } catch (e) {
      debugPrint('ADVANCE STATUS FAILED: $e');
      rethrow;
    }
  }

  /// Withdraws a pending booking request by a Truck Owner.
  Future<void> withdrawBooking(BookingModel booking, AppUser currentUser) async {
    debugPrint('WITHDRAW BOOKING START: bookingId=${booking.bookingId}');
    try {
      final batch = _firestore.batch();
      final bookingRef = _firestore.collection('bookings').doc(booking.bookingId);
      
      batch.update(bookingRef, {
        'status': 'withdrawn',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final notifRef = _firestore.collection('notifications').doc();
      final notif = NotificationModel(
        notificationId: notifRef.id,
        uid: booking.providerUid,
        title: 'Booking Request Withdrawn',
        message: '${currentUser.displayName} withdrew their request for Load #${booking.loadId.substring(0, 8).toUpperCase()}.',
        type: 'operational',
        createdAt: DateTime.now(),
      );
      batch.set(notifRef, notif.toJson());

      await batch.commit();
      debugPrint('WITHDRAW BOOKING COMPLETE');
    } catch (e) {
      debugPrint('WITHDRAW BOOKING FAILED: $e');
      rethrow;
    }
  }

  /// Atomically deletes an open load and any associated pending/rejected/withdrawn bookings.
  Future<void> deleteLoadAtomic(LoadModel load, AppUser currentUser) async {
    debugPrint('DELETING LOAD START: loadId=${load.loadId}');
    try {
      if (load.status != 'open') {
        throw Exception('Only open loads can be deleted.');
      }

      // Query all bookings for this load
      debugPrint('READING BOOKINGS FOR LOAD: ${load.loadId}');
      final bookingsQuery = await _firestore
          .collection('bookings')
          .where('loadId', isEqualTo: load.loadId)
          .get(const GetOptions(source: Source.server));

      for (var doc in bookingsQuery.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'accepted') {
          throw Exception('Cannot delete a load with an accepted booking.');
        }
      }

      // Query if any trip exists just in case
      debugPrint('READING TRIP: ${load.loadId}');
      final tripSnap = await _firestore.collection('trips').doc(load.loadId).get(const GetOptions(source: Source.server));
      if (tripSnap.exists) {
        throw Exception('Cannot delete a load that has an active trip.');
      }

      final batch = _firestore.batch();

      // Delete all related bookings
      for (var doc in bookingsQuery.docs) {
        debugPrint('DELETING BOOKING: ${doc.id}');
        batch.delete(doc.reference);
      }

      // Delete the load
      debugPrint('DELETING LOAD: ${load.loadId}');
      batch.delete(_firestore.collection('loads').doc(load.loadId));

      await batch.commit();
      debugPrint('LOAD DELETED');
      debugPrint('FIRESTORE SECURITY FLOW STABILIZED');
    } catch (e) {
      debugPrint('DELETE LOAD FAILED: $e');
      rethrow;
    }
  }
}
