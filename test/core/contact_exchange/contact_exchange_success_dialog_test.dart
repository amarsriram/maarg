import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maarg/core/models/contact_exchange_model.dart';
import 'package:maarg/core/repositories/contact_exchange_repository.dart';
import 'package:maarg/core/widgets/contact_exchange_card.dart';
import 'package:maarg/core/widgets/contact_exchange_success_dialog.dart';

void main() {
  Widget buildTestDialog({
    required String bookingId,
    required String currentUserUid,
    required ContactExchangeModel? exchangeState,
    bool isLoading = false,
  }) {
    return ProviderScope(
      overrides: [
        contactExchangeProvider.overrideWithProvider(
          (String id) {
            expect(id, equals(bookingId));
            if (isLoading) {
              return StreamProvider.autoDispose<ContactExchangeModel?>((ref) => const Stream.empty());
            }
            return StreamProvider.autoDispose<ContactExchangeModel?>((ref) => Stream.value(exchangeState));
          },
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ContactExchangeSuccessDialog(
                      bookingId: bookingId,
                      currentUserUid: currentUserUid,
                      onViewAction: () {},
                      viewActionLabel: 'View Load',
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ContactExchangeSuccessDialog UX Tests', () {
    testWidgets('Provider acceptance success -> Shows "Booking Accepted" and other party phone', (tester) async {
      final exchange = ContactExchangeModel(
        bookingId: 'load1_truck1',
        loadId: 'load1',
        truckOwnerUid: 'truck1',
        truckOwnerPhone: '+919999999999',
        providerUid: 'prov1',
        providerPhone: '+918888888888',
        status: 'accepted',
        unlockedAt: DateTime.now(),
      );

      await tester.pumpWidget(buildTestDialog(
        bookingId: 'load1_truck1',
        currentUserUid: 'prov1', // Current user is Provider
        exchangeState: exchange,
      ));

      // Open Dialog
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Check text
      expect(find.text('Booking Accepted'), findsOneWidget);
      expect(find.text('Contact exchanged successfully.'), findsOneWidget);
      expect(find.text('View Load'), findsOneWidget);
      
      // Card is rendered
      expect(find.byType(ContactExchangeCard), findsOneWidget);
      // Provider sees truck owner's phone
      expect(find.text('+919999999999'), findsOneWidget);
      // Ensure provider's own phone is not visible
      expect(find.text('+918888888888'), findsNothing);
    });

    testWidgets('Pending exchange -> Phone not shown safely', (tester) async {
      final exchange = ContactExchangeModel(
        bookingId: 'load1_truck1',
        loadId: 'load1',
        truckOwnerUid: 'truck1',
        truckOwnerPhone: '+919999999999',
        providerUid: 'prov1',
        providerPhone: '+918888888888',
        status: 'pending', // Pending unexpectedly
      );

      await tester.pumpWidget(buildTestDialog(
        bookingId: 'load1_truck1',
        currentUserUid: 'prov1',
        exchangeState: exchange,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should show the locked UI from ContactExchangeCard
      expect(find.byType(ContactExchangeCard), findsOneWidget);
      expect(find.text('+919999999999'), findsNothing);
      expect(find.text('+918888888888'), findsNothing);
    });

    testWidgets('Missing exchange -> Safe UI', (tester) async {
      await tester.pumpWidget(buildTestDialog(
        bookingId: 'load1_truck1',
        currentUserUid: 'prov1',
        exchangeState: null,
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Should safely show the locked UI
      expect(find.byType(ContactExchangeCard), findsOneWidget);
      expect(find.text('+919999999999'), findsNothing);
    });
  });
}
