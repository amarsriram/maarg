import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/load_model.dart';
import '../models/payment_model.dart';
import '../models/notification_model.dart';
import '../../features/auth/domain/user_model.dart';
import '../services/analytics_service.dart';
import '../services/observability_service.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(FirebaseFirestore.instance);
});

final paymentStreamProvider = StreamProvider.family<PaymentModel?, String>((ref, loadId) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.watchPayment(loadId);
});

class PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepository(this._firestore);

  Stream<PaymentModel?> watchPayment(String loadId) {
    return _firestore.collection('payments').doc(loadId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return PaymentModel.fromJson(snap.data()!, snap.id);
    });
  }

  Future<void> markAsPaid(LoadModel load, AppUser currentUser) async {
    try {
      if (currentUser.id != load.providerUid) {
        throw Exception('Only the Provider can mark the payment as paid.');
      }
      
      final truckOwnerUid = load.assignedTruckOwnerUid;
      if (truckOwnerUid == null) {
        throw Exception('No truck owner is assigned to this load.');
      }

      await _firestore.runTransaction((transaction) async {
        final loadRef = _firestore.collection('loads').doc(load.loadId);
        final loadSnap = await transaction.get(loadRef);

        if (!loadSnap.exists) {
          throw Exception('Load not found.');
        }

        final currentStatus = loadSnap.data()!['status'] as String?;
        if (currentStatus != 'delivered' && currentStatus != 'completed') {
          throw Exception('Payment can only be marked after the trip is delivered.');
        }

        final paymentRef = _firestore.collection('payments').doc(load.loadId);
        final paymentSnap = await transaction.get(paymentRef);
        
        if (paymentSnap.exists) {
          throw Exception('Payment has already been marked.');
        }

        final payment = PaymentModel(
          paymentId: load.loadId,
          loadId: load.loadId,
          providerUid: currentUser.id,
          truckOwnerUid: truckOwnerUid,
          amount: load.budget,
          currency: 'INR',
          status: 'marked_paid',
          markedPaidAt: DateTime.now(),
          markedPaidBy: currentUser.id,
        );

        transaction.set(paymentRef, payment.toJson());

        final notifRef = _firestore.collection('notifications').doc();
        final notif = NotificationModel(
          notificationId: notifRef.id,
          uid: truckOwnerUid,
          title: 'Payment Marked as Paid',
          message: '${currentUser.displayName} has marked the payment as paid. Please confirm receipt.',
          type: 'PAYMENT_MARKED_PAID',
          relatedLoadId: load.loadId,
          createdAt: DateTime.now(),
          priority: 'high',
        );
        transaction.set(notifRef, notif.toJson());
      });

      AnalyticsService.logPaymentStatusChanged(
        loadId: load.loadId,
        newStatus: 'marked_paid',
      );
    } catch (e, stack) {
      ObservabilityService.reportNonFatalError(
        errorCode: 'PAYMENT_FAILURE',
        exception: e,
        stackTrace: stack,
        context: 'markAsPaid',
      );
      if (kDebugMode) {
        debugPrint('MARK AS PAID FAILED: $e');
      }
      rethrow;
    }
  }

  Future<void> confirmPayment(String loadId, AppUser currentUser) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final paymentRef = _firestore.collection('payments').doc(loadId);
        final paymentSnap = await transaction.get(paymentRef);

        if (!paymentSnap.exists) {
          throw Exception('Payment record not found.');
        }

        final data = paymentSnap.data()!;
        if (data['truckOwnerUid'] != currentUser.id) {
          throw Exception('Only the assigned Truck Owner can confirm payment.');
        }
        
        if (data['status'] != 'marked_paid') {
          throw Exception('Payment is not in a state that can be confirmed.');
        }

        transaction.update(paymentRef, {
          'status': 'confirmed',
          'confirmedAt': FieldValue.serverTimestamp(),
          'confirmedBy': currentUser.id,
        });

        final notifRef = _firestore.collection('notifications').doc();
        final notif = NotificationModel(
          notificationId: notifRef.id,
          uid: data['providerUid'] as String,
          title: 'Payment Confirmed',
          message: '${currentUser.displayName} has confirmed receipt of the payment.',
          type: 'PAYMENT_CONFIRMED',
          relatedLoadId: loadId,
          createdAt: DateTime.now(),
        );
        transaction.set(notifRef, notif.toJson());
      });

      AnalyticsService.logPaymentStatusChanged(
        loadId: loadId,
        newStatus: 'confirmed',
      );
    } catch (e, stack) {
      ObservabilityService.reportNonFatalError(
        errorCode: 'PAYMENT_FAILURE',
        exception: e,
        stackTrace: stack,
        context: 'confirmPayment',
      );
      if (kDebugMode) {
        debugPrint('CONFIRM PAYMENT FAILED: $e');
      }
      rethrow;
    }
  }

  Future<void> disputePayment(String loadId, AppUser currentUser) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final paymentRef = _firestore.collection('payments').doc(loadId);
        final paymentSnap = await transaction.get(paymentRef);

        if (!paymentSnap.exists) {
          throw Exception('Payment record not found.');
        }

        final data = paymentSnap.data()!;
        if (data['truckOwnerUid'] != currentUser.id) {
          throw Exception('Only the assigned Truck Owner can dispute payment.');
        }
        
        if (data['status'] != 'marked_paid') {
          throw Exception('Payment is not in a state that can be disputed.');
        }

        transaction.update(paymentRef, {
          'status': 'disputed',
          'disputedAt': FieldValue.serverTimestamp(),
          'disputedBy': currentUser.id,
        });

        final notifRef = _firestore.collection('notifications').doc();
        final notif = NotificationModel(
          notificationId: notifRef.id,
          uid: data['providerUid'] as String,
          title: 'Payment Disputed',
          message: '${currentUser.displayName} has reported an issue with the payment. Please contact support.',
          type: 'PAYMENT_DISPUTED',
          relatedLoadId: loadId,
          createdAt: DateTime.now(),
          priority: 'high',
        );
        transaction.set(notifRef, notif.toJson());
      });

      AnalyticsService.logPaymentStatusChanged(
        loadId: loadId,
        newStatus: 'disputed',
      );
    } catch (e, stack) {
      ObservabilityService.reportNonFatalError(
        errorCode: 'PAYMENT_FAILURE',
        exception: e,
        stackTrace: stack,
        context: 'disputePayment',
      );
      if (kDebugMode) {
        debugPrint('DISPUTE PAYMENT FAILED: $e');
      }
      rethrow;
    }
  }
}
