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
          throw 'Load no longer exists.';
        }

        final loadData = loadSnap.data()!;
        final currentStatusStr = loadData['status'] as String?;
        final currentStatus = TripStatusExtension.fromString(currentStatusStr);

        if (currentStatus != TripStatus.open) {
          throw 'This load has already been assigned.';
        }

        final bookingRef = _firestore.collection('bookings').doc(booking.bookingId);
        final bookingSnap = await transaction.get(bookingRef);

        if (!bookingSnap.exists) {
          throw 'Booking no longer exists.';
        }

        final bookingStatus = bookingSnap.data()!['status'] as String?;
        
        if (bookingStatus != 'pending') {
          throw 'This booking has already been processed.';
        }

        final tripRef = _firestore.collection('trips').doc(booking.loadId);
        final tripSnap = await transaction.get(tripRef);
        if (tripSnap.exists) {
          throw 'This load already has an active trip.';
        }

        // READ ALL LOSER BOOKINGS BEFORE ANY WRITES
        final List<DocumentSnapshot<Map<String, dynamic>>> loserSnaps = [];
        for (final doc in pendingQuery.docs) {
          if (doc.id != booking.bookingId) {
            final otherBookingRef = _firestore.collection('bookings').doc(doc.id);
            // Read to ensure it hasn't changed (locks the document in the transaction)
            final snap = await transaction.get(otherBookingRef);
            loserSnaps.add(snap);
          }
        }

        // Update booking status to accepted
        try {
          transaction.update(bookingRef, {
            'status': 'accepted',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FAILED AT STEP 1: $e');
          }
          rethrow;
        }

        // Update load to assigned
        try {
          transaction.update(loadRef, {
            'status': TripStatus.assigned.name,
            'assignedTruckOwnerUid': booking.truckOwnerUid,
            'assignedTruckOwnerName': booking.truckOwnerName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FAILED AT STEP 2: $e');
          }
          rethrow;
        }

        // Create trip document
        try {
          final tripData = {
            'tripId': booking.loadId,
            'loadId': booking.loadId,
            'providerUid': currentUser.id, // Forcing current user ID to ensure rule match
            'truckOwnerUid': booking.truckOwnerUid,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          transaction.set(tripRef, tripData);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FAILED AT STEP 3: $e');
          }
          rethrow;
        }

        // Create trip event
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
          if (kDebugMode) {
            debugPrint('FAILED AT STEP 4: $e');
          }
          rethrow;
        }

        // Send notification to truck owner
        try {
          final notifRef = _firestore.collection('notifications').doc();
          final notif = NotificationModel(
            notificationId: notifRef.id,
            uid: booking.truckOwnerUid,
            title: 'Booking Accepted',
            message: '${currentUser.displayName} accepted your request.\n${booking.pickupLocation} → ${booking.dropLocation}',
            type: 'BOOKING_ACCEPTED',
            createdAt: DateTime.now(),
          );
          transaction.set(notifRef, notif.toJson());
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FAILED AT STEP 5: $e');
          }
          rethrow;
        }

        // Reject other pending bookings atomically
        for (final snap in loserSnaps) {
          if (snap.exists && snap.data()?['status'] == 'pending') {
            transaction.update(snap.reference, {
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
                message: '${currentUser.displayName} assigned the load to someone else.\n${booking.pickupLocation} → ${booking.dropLocation}',
                type: 'BOOKING_REJECTED',
                createdAt: DateTime.now(),
              );
              transaction.set(notifRef, notif.toJson());
            }
          }
        }
        
      });

    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('ACCEPT BOOKING FAILED: $e');
      }
      if (kDebugMode) {
        debugPrint('ACCEPT BOOKING STACK: $stack');
      }
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
        message: '${currentUser.displayName} declined your request.\n${booking.pickupLocation} → ${booking.dropLocation}',
        type: 'BOOKING_REJECTED',
        createdAt: DateTime.now(),
      );
      batch.set(notifRef, notif.toJson());

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('REJECT BOOKING FAILED: $e');
      }
      rethrow;
    }
  }

  /// Requests a booking using a TRANSACTION to prevent duplicates.
  Future<void> requestBooking(LoadModel load, AppUser currentUser) async {

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
          message: '${currentUser.displayName} requested to carry the load.\n${load.pickupLocation} → ${load.dropLocation}',
          type: 'NEW_BOOKING_REQUEST',
          createdAt: DateTime.now(),
        );
        transaction.set(notifRef, notif.toJson());
      });

    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('REQUEST BOOKING FAILED: $e');
      }
      if (kDebugMode) {
        debugPrint('REQUEST BOOKING STACK: $stack');
      }
      rethrow;
    }
  }

  Future<void> advanceLoadStatus(LoadModel load, TripStatus nextStatus, AppUser currentUser) async {

    try {
      final currentStatus = load.tripStatus;
      
      if (!currentStatus.canTransitionTo(nextStatus)) {
        throw Exception('Invalid state transition from ${currentStatus.name} to ${nextStatus.name}');
      }

      // ── Role-based enforcement ──
      // Truck Owner owns field operations: en_route_pickup, loaded, in_transit, delivered
      // Provider owns business confirmation: completed
      const truckOwnerStatuses = {
        TripStatus.en_route_pickup,
        TripStatus.loaded,
        TripStatus.in_transit,
        TripStatus.delivered,
      };
      const providerStatuses = {
        TripStatus.completed,
      };

      if (currentUser.role == UserRole.truckOwner && !truckOwnerStatuses.contains(nextStatus)) {
        throw Exception('Truck Owners can only update field-level statuses (departure, loaded, transit, delivered).');
      }
      if (currentUser.role == UserRole.provider && !providerStatuses.contains(nextStatus)) {
        throw Exception('Providers can only confirm trip completion.');
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
        final isCompleted = nextStatus == TripStatus.completed;
        
        String actionMessage;
        switch (nextStatus) {
          case TripStatus.en_route_pickup:
            actionMessage = '${currentUser.displayName} is heading to pickup.';
            break;
          case TripStatus.loaded:
            actionMessage = '${currentUser.displayName} loaded the cargo.';
            break;
          case TripStatus.in_transit:
            actionMessage = '${currentUser.displayName} started the journey.';
            break;
          case TripStatus.delivered:
            actionMessage = '${currentUser.displayName} delivered the shipment.';
            break;
          case TripStatus.completed:
            actionMessage = '${currentUser.displayName} completed the trip.';
            break;
          default:
            actionMessage = '${currentUser.displayName} updated the trip status to ${nextStatus.displayName}.';
        }

        final notif = NotificationModel(
          notificationId: notifRef.id,
          uid: recipientUid,
          title: isCompleted ? 'Trip Completed' : 'Trip Status Update',
          message: '$actionMessage\n${load.pickupLocation} → ${load.dropLocation}',
          type: isCompleted ? 'TRIP_COMPLETED' : 'TRIP_STATUS_UPDATE',
          createdAt: DateTime.now(),
        );
        batch.set(notifRef, notif.toJson());
      }

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ADVANCE STATUS FAILED: $e');
      }
      rethrow;
    }
  }

  /// Withdraws a pending booking request by a Truck Owner.
  Future<void> withdrawBooking(BookingModel booking, AppUser currentUser) async {
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
        message: '${currentUser.displayName} withdrew their request.\n${booking.pickupLocation} → ${booking.dropLocation}',
        type: 'BOOKING_WITHDRAWN',
        createdAt: DateTime.now(),
      );
      batch.set(notifRef, notif.toJson());

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WITHDRAW BOOKING FAILED: $e');
      }
      rethrow;
    }
  }

  /// Atomically deletes an open load and any associated pending/rejected/withdrawn bookings.
  Future<void> deleteLoadAtomic(LoadModel load, AppUser currentUser) async {
    try {
      if (load.status != 'open') {
        throw Exception('Only open loads can be deleted.');
      }

      // Query all bookings for this load
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
      final tripSnap = await _firestore.collection('trips').doc(load.loadId).get(const GetOptions(source: Source.server));
      if (tripSnap.exists) {
        throw Exception('Cannot delete a load that has an active trip.');
      }

      final batch = _firestore.batch();

      // Delete all related bookings
      for (var doc in bookingsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete the load
      batch.delete(_firestore.collection('loads').doc(load.loadId));

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DELETE LOAD FAILED: $e');
      }
      rethrow;
    }
  }
}
