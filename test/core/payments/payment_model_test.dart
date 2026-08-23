import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maarg/core/models/payment_model.dart';

void main() {
  group('PaymentModel Tests', () {
    test('fromJson handles standard response correctly', () {
      final now = DateTime.now();
      final json = {
        'loadId': 'load-123',
        'providerUid': 'p-1',
        'truckOwnerUid': 't-1',
        'amount': '5000',
        'currency': 'INR',
        'status': 'marked_paid',
        'markedPaidAt': Timestamp.fromDate(now),
        'markedPaidBy': 'p-1',
      };

      final payment = PaymentModel.fromJson(json, 'pay-123');
      
      expect(payment.paymentId, 'pay-123');
      expect(payment.loadId, 'load-123');
      expect(payment.providerUid, 'p-1');
      expect(payment.amount, '5000');
      expect(payment.status, 'marked_paid');
      // Truncating milliseconds due to possible precision differences
      expect(payment.markedPaidAt?.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });

    test('fromJson provides sensible defaults for missing non-nullable fields', () {
      final json = <String, dynamic>{};

      final payment = PaymentModel.fromJson(json, 'pay-123');

      expect(payment.paymentId, 'pay-123');
      expect(payment.loadId, '');
      expect(payment.currency, 'INR');
      expect(payment.status, 'pending');
      expect(payment.markedPaidAt, isNull);
    });

    test('toJson serializes correctly', () {
      final date = DateTime(2026, 1, 1);
      final payment = PaymentModel(
        paymentId: 'pay-123',
        loadId: 'load-123',
        providerUid: 'p-1',
        truckOwnerUid: 't-1',
        amount: '12000',
        status: 'confirmed',
        confirmedAt: date,
        confirmedBy: 't-1',
      );

      final json = payment.toJson();
      expect(json['loadId'], 'load-123');
      expect(json['amount'], '12000');
      expect(json['status'], 'confirmed');
      expect(json['confirmedBy'], 't-1');
      expect(json['confirmedAt'], isA<Timestamp>());
      
      final timestamp = json['confirmedAt'] as Timestamp;
      expect(timestamp.toDate(), equals(date));
    });
  });
}
