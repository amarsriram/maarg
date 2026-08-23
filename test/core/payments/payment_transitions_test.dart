import 'package:flutter_test/flutter_test.dart';
import 'package:maarg/core/models/payment_model.dart';

void main() {
  group('Payment Transitions', () {
    PaymentModel createWithStatus(String status) {
      return PaymentModel(
        paymentId: 'pay-123',
        loadId: 'load-123',
        providerUid: 'p-1',
        truckOwnerUid: 't-1',
        amount: '5000',
        status: status,
      );
    }

    test('pending can only transition to marked_paid', () {
      final payment = createWithStatus('pending');
      expect(payment.canTransitionTo('marked_paid'), isTrue);
      expect(payment.canTransitionTo('confirmed'), isFalse);
      expect(payment.canTransitionTo('disputed'), isFalse);
    });

    test('marked_paid can transition to confirmed or disputed', () {
      final payment = createWithStatus('marked_paid');
      expect(payment.canTransitionTo('confirmed'), isTrue);
      expect(payment.canTransitionTo('disputed'), isTrue);
      expect(payment.canTransitionTo('pending'), isFalse);
    });

    test('confirmed is a terminal state', () {
      final payment = createWithStatus('confirmed');
      expect(payment.canTransitionTo('pending'), isFalse);
      expect(payment.canTransitionTo('marked_paid'), isFalse);
      expect(payment.canTransitionTo('disputed'), isFalse);
    });

    test('disputed is a terminal state', () {
      final payment = createWithStatus('disputed');
      expect(payment.canTransitionTo('pending'), isFalse);
      expect(payment.canTransitionTo('marked_paid'), isFalse);
      expect(payment.canTransitionTo('confirmed'), isFalse);
    });
  });
}
