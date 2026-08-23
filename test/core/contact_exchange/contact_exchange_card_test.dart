import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maarg/core/models/contact_exchange_model.dart';
import 'package:maarg/core/widgets/contact_exchange_card.dart';

/// Wraps a widget in the minimal Material/MediaQuery scaffolding required by
/// PremiumCard (which calls Theme.of(context)).
Widget buildTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

ContactExchangeModel _makeExchange({
  String status = 'pending',
  String? providerPhone,
}) {
  return ContactExchangeModel(
    bookingId: 'load1_truck456',
    loadId: 'load1',
    truckOwnerUid: 'truck456',
    truckOwnerPhone: '+918888888888',
    providerUid: 'prov123',
    providerPhone: providerPhone,
    status: status,
  );
}

void main() {
  group('ContactExchangeCard — pending state', () {
    testWidgets('shows locked UI and hides phone when status is pending', (tester) async {
      final exchange = _makeExchange(status: 'pending');

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'truck456',
          exchange: exchange,
        ),
      ));

      // Header label
      expect(find.text('Contact Protected'), findsOneWidget);
      // Informational message shown instead of phone
      expect(find.textContaining('Contact details will be available'), findsOneWidget);
      // No phone number visible
      expect(find.text('+918888888888'), findsNothing);
      expect(find.text('+919999999999'), findsNothing);
      // No call/copy actions
      expect(find.text('Call'), findsNothing);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('Provider also sees locked UI on pending exchange', (tester) async {
      final exchange = _makeExchange(status: 'pending');

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'prov123',
          exchange: exchange,
        ),
      ));

      expect(find.text('Contact Protected'), findsOneWidget);
      expect(find.textContaining('Contact details will be available'), findsOneWidget);
      expect(find.text('+918888888888'), findsNothing);
    });

    testWidgets('null exchange renders locked/pending UI safely', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const ContactExchangeCard(
          currentUserUid: 'truck456',
          exchange: null,
        ),
      ));

      expect(find.text('Contact Protected'), findsOneWidget);
      expect(find.textContaining('Contact details will be available'), findsOneWidget);
      expect(find.text('+918888888888'), findsNothing);
    });
  });

  group('ContactExchangeCard — accepted state', () {
    testWidgets('Truck Owner sees Provider phone after acceptance', (tester) async {
      final exchange = _makeExchange(
        status: 'accepted',
        providerPhone: '+919999999999',
      );

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'truck456', // Truck Owner
          exchange: exchange,
        ),
      ));

      expect(find.text('Contact Exchanged'), findsOneWidget);
      // Provider's phone visible to Truck Owner
      expect(find.text('+919999999999'), findsOneWidget);
      // Truck Owner's OWN phone is not shown
      expect(find.text('+918888888888'), findsNothing);
      // Actions present
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('Provider sees Truck Owner phone after acceptance', (tester) async {
      final exchange = _makeExchange(
        status: 'accepted',
        providerPhone: '+919999999999',
      );

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'prov123', // Provider
          exchange: exchange,
        ),
      ));

      expect(find.text('Contact Exchanged'), findsOneWidget);
      // Truck Owner's phone visible to Provider
      expect(find.text('+918888888888'), findsOneWidget);
      // Provider's OWN phone is not shown
      expect(find.text('+919999999999'), findsNothing);
    });

    testWidgets('onCallPressed callback fires with correct phone', (tester) async {
      final exchange = _makeExchange(
        status: 'accepted',
        providerPhone: '+919999999999',
      );
      String? calledWith;

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'truck456',
          exchange: exchange,
          onCallPressed: (phone) => calledWith = phone,
        ),
      ));

      await tester.tap(find.text('Call'));
      await tester.pump();

      expect(calledWith, equals('+919999999999'));
    });

    testWidgets('onCopyPressed callback fires with correct phone', (tester) async {
      final exchange = _makeExchange(
        status: 'accepted',
        providerPhone: '+919999999999',
      );
      String? copiedWith;

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'truck456',
          exchange: exchange,
          onCopyPressed: (phone) => copiedWith = phone,
        ),
      ));

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(copiedWith, equals('+919999999999'));
    });

    testWidgets('unrelated UID sees locked fallback even on accepted exchange', (tester) async {
      final exchange = _makeExchange(
        status: 'accepted',
        providerPhone: '+919999999999',
      );

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'evil_outsider',
          exchange: exchange,
        ),
      ));

      // No phone shown to an unrecognized UID
      expect(find.text('+919999999999'), findsNothing);
      expect(find.text('+918888888888'), findsNothing);
      // Falls back to pending body
      expect(find.textContaining('Contact details will be available'), findsOneWidget);
    });
  });

  group('ContactExchangeCard — withdrawn state', () {
    testWidgets('shows closed UI and hides phone when withdrawn', (tester) async {
      final exchange = _makeExchange(status: 'withdrawn');

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'truck456',
          exchange: exchange,
        ),
      ));

      expect(find.text('Contact Exchange Closed'), findsOneWidget);
      expect(find.textContaining('was withdrawn'), findsOneWidget);
      expect(find.text('+918888888888'), findsNothing);
      expect(find.text('Call'), findsNothing);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('Provider also sees closed UI on withdrawn exchange', (tester) async {
      final exchange = _makeExchange(status: 'withdrawn');

      await tester.pumpWidget(buildTestApp(
        ContactExchangeCard(
          currentUserUid: 'prov123',
          exchange: exchange,
        ),
      ));

      expect(find.text('Contact Exchange Closed'), findsOneWidget);
      expect(find.text('+919999999999'), findsNothing);
    });
  });

  group('ContactExchangeCard — missing document', () {
    testWidgets('null exchange shows safe empty/pending state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const ContactExchangeCard(
          currentUserUid: 'truck456',
          exchange: null,
        ),
      ));

      // Should not crash and should show the locked pending UI
      expect(tester.takeException(), isNull);
      expect(find.text('Contact Protected'), findsOneWidget);
      expect(find.text('Contact Exchanged'), findsNothing);
      expect(find.text('Contact Exchange Closed'), findsNothing);
    });
  });
}
