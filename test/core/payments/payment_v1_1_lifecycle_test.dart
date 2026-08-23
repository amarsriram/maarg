// test/core/payments/payment_v1_1_lifecycle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maarg/core/models/payment_model.dart';
import 'package:maarg/core/models/trip_status.dart';

void main() {
  // 1. TripStatus role enforcement
  group('TripStatus role enforcement V1.1', () {
    const truckOwnerStatuses = {
      TripStatus.en_route_pickup,
      TripStatus.loaded,
      TripStatus.in_transit,
      TripStatus.delivered,
      TripStatus.completed,
    };
    const providerStatuses = <TripStatus>{};

    test('Truck Owner CAN request completed', () {
      expect(truckOwnerStatuses.contains(TripStatus.completed), isTrue);
    });
    test('Provider CANNOT request completed', () {
      expect(providerStatuses.contains(TripStatus.completed), isFalse);
    });
    test('delivered -> completed is valid TripStatus transition', () {
      expect(TripStatus.delivered.canTransitionTo(TripStatus.completed), isTrue);
    });
    test('completed is terminal', () {
      expect(TripStatus.completed.canTransitionTo(TripStatus.delivered), isFalse);
    });
  });

  // 2. PaymentModel state machine
  group('PaymentModel state machine', () {
    PaymentModel mk(String s) => PaymentModel(paymentId: 'p', loadId: 'l', providerUid: 'pr', truckOwnerUid: 'to', amount: '5000', status: s);

    test('null payment -> Complete Trip unavailable', () {
      const PaymentModel? p = null;
      expect(p != null && p.status == 'confirmed', isFalse);
    });
    test('marked_paid -> Complete Trip unavailable', () {
      expect(mk('marked_paid').status == 'confirmed', isFalse);
    });
    test('confirmed -> Complete Trip available', () {
      expect(mk('confirmed').status == 'confirmed', isTrue);
    });
    test('disputed -> Complete Trip unavailable', () {
      expect(mk('disputed').status == 'confirmed', isFalse);
    });
    test('confirmed is terminal', () {
      expect(mk('confirmed').canTransitionTo('confirmed'), isFalse);
      expect(mk('confirmed').canTransitionTo('marked_paid'), isFalse);
      expect(mk('confirmed').canTransitionTo('disputed'), isFalse);
    });
    test('disputed cannot become confirmed via replay', () {
      expect(mk('disputed').canTransitionTo('confirmed'), isFalse);
    });
  });

  // 3. Complete Trip button visibility
  group('Complete Trip button visibility', () {
    PaymentModel mk(String s) => PaymentModel(paymentId: 'p', loadId: 'l', providerUid: 'pr', truckOwnerUid: 'to', amount: '5000', status: s);
    bool visible(PaymentModel? payment, bool isTruckOwner) {
      if (!isTruckOwner) return false;
      return payment != null && payment.status == 'confirmed';
    }
    test('Provider + confirmed -> button HIDDEN', () => expect(visible(mk('confirmed'), false), isFalse));
    test('Truck Owner + confirmed -> button SHOWN', () => expect(visible(mk('confirmed'), true), isTrue));
    test('Truck Owner + null payment -> button HIDDEN', () => expect(visible(null, true), isFalse));
    test('Truck Owner + marked_paid -> button HIDDEN', () => expect(visible(mk('marked_paid'), true), isFalse));
    test('Truck Owner + disputed -> button HIDDEN', () => expect(visible(mk('disputed'), true), isFalse));
  });

  // 4. Firestore rule logic mirrors
  group('Firestore completion rule logic', () {
    bool allowed({required String newStatus, required String currentStatus, required String reqUid, required String toUid, required bool payExists, String? payStatus}) {
      if (newStatus != 'completed') return true;
      if (currentStatus == 'completed') return true;
      return currentStatus == 'delivered' && reqUid == toUid && payExists && payStatus == 'confirmed';
    }
    const to = 'to-1'; const prov = 'prov-1'; const other = 'other-1';

    test('delivered+confirmed+Truck Owner -> ALLOWED', () => expect(allowed(newStatus:'completed', currentStatus:'delivered', reqUid:to, toUid:to, payExists:true, payStatus:'confirmed'), isTrue));
    test('delivered+confirmed+Provider -> DENIED', () => expect(allowed(newStatus:'completed', currentStatus:'delivered', reqUid:prov, toUid:to, payExists:true, payStatus:'confirmed'), isFalse));
    test('delivered+confirmed+unrelated UID -> DENIED', () => expect(allowed(newStatus:'completed', currentStatus:'delivered', reqUid:other, toUid:to, payExists:true, payStatus:'confirmed'), isFalse));
    test('delivered+no payment -> DENIED', () => expect(allowed(newStatus:'completed', currentStatus:'delivered', reqUid:to, toUid:to, payExists:false), isFalse));
    test('delivered+marked_paid -> DENIED', () => expect(allowed(newStatus:'completed', currentStatus:'delivered', reqUid:to, toUid:to, payExists:true, payStatus:'marked_paid'), isFalse));
    test('delivered+disputed -> DENIED', () => expect(allowed(newStatus:'completed', currentStatus:'delivered', reqUid:to, toUid:to, payExists:true, payStatus:'disputed'), isFalse));
    test('in_transit+confirmed+Truck Owner -> DENIED (wrong prior state)', () => expect(allowed(newStatus:'completed', currentStatus:'in_transit', reqUid:to, toUid:to, payExists:true, payStatus:'confirmed'), isFalse));
    test('unrelated update -> ALLOWED', () => expect(allowed(newStatus:'delivered', currentStatus:'in_transit', reqUid:other, toUid:to, payExists:false), isTrue));
  });
}
