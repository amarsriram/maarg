import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maarg/core/models/contact_exchange_model.dart';
import 'package:maarg/core/models/load_model.dart';
import 'package:maarg/core/repositories/contact_exchange_repository.dart';
import 'package:maarg/core/widgets/contact_exchange_card.dart';
import 'package:maarg/features/auth/data/auth_repository.dart';
import 'package:maarg/features/auth/domain/user_model.dart';
import 'package:maarg/features/dashboard/presentation/load_detail_screen.dart';

void main() {
  LoadModel makeLoad({
    String loadId = 'load_123',
    String providerUid = 'prov_abc',
    String? assignedTruckOwnerUid,
  }) {
    return LoadModel(
      loadId: loadId,
      providerUid: providerUid,
      providerName: 'Test Provider',
      pickupLocation: 'City A',
      dropLocation: 'City B',
      pickupDate: '2026-08-21',
      materialType: 'Steel',
      weight: '10 Tons',
      truckType: 'Open',
      budget: '10000',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: assignedTruckOwnerUid != null ? 'assigned' : 'open',
      assignedTruckOwnerUid: assignedTruckOwnerUid,
      assignedTruckOwnerName: assignedTruckOwnerUid != null ? 'Test Truck' : null,
    );
  }

  AppUser makeUser(String uid, UserRole role) {
    return AppUser(
      id: uid,
      email: '$uid@test.com',
      role: role,
      profileCompleted: true,
    );
  }

  Widget buildTestApp({
    required AppUser user,
    required LoadModel load,
    required String expectedBookingId,
  }) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        // Override the provider to intercept the requested bookingId and avoid Firestore
        contactExchangeProvider.overrideWithProvider(
          (String bookingId) {
            // Assert that the requested booking ID matches what we expect!
            expect(bookingId, equals(expectedBookingId));
            return StreamProvider.autoDispose<ContactExchangeModel?>((ref) => Stream.value(null));
          },
        ),
      ],
      child: MaterialApp(
        home: LoadDetailScreen(
          loadId: load.loadId,
          initialLoad: load,
        ),
      ),
    );
  }

  group('LoadDetailScreen Contact Exchange Integration', () {
    testWidgets('Truck Owner derives correct bookingId (\${loadId}_\${currentUser.uid})', (tester) async {
      final truckOwner = makeUser('truck_789', UserRole.truckOwner);
      final load = makeLoad(loadId: 'load_123'); // Unassigned load

      await tester.pumpWidget(buildTestApp(
        user: truckOwner,
        load: load,
        expectedBookingId: 'load_123_truck_789',
      ));
      await tester.pumpAndSettle();

      // Card should be rendered (with locked UI due to null exchange override)
      expect(find.byType(ContactExchangeCard), findsOneWidget);
    });

    testWidgets('Provider derives bookingId from assignedTruckOwnerUid', (tester) async {
      final provider = makeUser('prov_abc', UserRole.provider);
      final load = makeLoad(
        loadId: 'load_123',
        providerUid: 'prov_abc',
        assignedTruckOwnerUid: 'truck_789', // Assigned
      );

      await tester.pumpWidget(buildTestApp(
        user: provider,
        load: load,
        expectedBookingId: 'load_123_truck_789', // The provider's generated ID points to the assigned truck owner
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ContactExchangeCard), findsOneWidget);
    });

    testWidgets('Provider sees NO card if missing assignedTruckOwnerUid', (tester) async {
      final provider = makeUser('prov_abc', UserRole.provider);
      final load = makeLoad(
        loadId: 'load_123',
        providerUid: 'prov_abc',
        assignedTruckOwnerUid: null, // Not assigned yet
      );

      bool providerQueried = false;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(provider)),
          contactExchangeProvider.overrideWithProvider(
            (String bookingId) {
              providerQueried = true;
              return StreamProvider.autoDispose<ContactExchangeModel?>((ref) => Stream.value(null));
            },
          ),
        ],
        child: MaterialApp(
          home: LoadDetailScreen(
            loadId: load.loadId,
            initialLoad: load,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Should completely bypass querying contact exchange
      expect(providerQueried, isFalse);
      expect(find.byType(ContactExchangeCard), findsNothing);
    });
  });
}
