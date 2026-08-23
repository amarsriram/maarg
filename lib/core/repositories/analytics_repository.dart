import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/trip_status.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(FirebaseFirestore.instance);
});

final providerAnalyticsProvider = StreamProvider.autoDispose.family<ProviderAnalytics, String>((ref, uid) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(ProviderAnalytics.empty());

  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.streamProviderAnalytics(uid).handleError((e) {
    if (kDebugMode) {
      debugPrint('STREAM ERROR: $e');
    }
  });
});

class ProviderAnalytics {
  final int activeShipments;
  final int completedShipments;
  final int delayedShipments;
  final int totalSpend;

  ProviderAnalytics({
    required this.activeShipments,
    required this.completedShipments,
    required this.delayedShipments,
    required this.totalSpend,
  });

  factory ProviderAnalytics.empty() {
    return ProviderAnalytics(
      activeShipments: 0,
      completedShipments: 0,
      delayedShipments: 0,
      totalSpend: 0,
    );
  }
}

class AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepository(this._firestore);

  /// Streams provider analytics using targeted status snapshots and count aggregations
  /// rather than downloading the entire historical load collection.
  Stream<ProviderAnalytics> streamProviderAnalytics(String providerUid) {
    return _firestore
        .collection('loads')
        .where('providerUid', isEqualTo: providerUid)
        .where('status', whereIn: [
          'assigned',
          'en_route_pickup',
          'loaded',
          'in_transit',
          'delivered',
          'disputed',
          'completed',
        ])
        .snapshots()
        .map((snapshot) {
      int active = 0;
      int completed = 0;
      int delayed = 0;
      int spend = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final statusStr = data['status'] as String?;
        final status = TripStatusExtension.fromString(statusStr);
        final budgetStr = data['budget'] as String? ?? '0';

        int budget = 0;
        try {
          final cleanStr = budgetStr.replaceAll(RegExp(r'[^0-9]'), '');
          if (cleanStr.isNotEmpty) {
            budget = int.parse(cleanStr);
          }
        } catch (_) {}

        if (status == TripStatus.completed) {
          completed++;
          spend += budget;
        } else if (status != TripStatus.open && status != TripStatus.cancelled && status != TripStatus.requested) {
          active++;
          if (status == TripStatus.disputed) {
            delayed++;
          }
        }
      }

      return ProviderAnalytics(
        activeShipments: active,
        completedShipments: completed,
        delayedShipments: delayed,
        totalSpend: spend,
      );
    });
  }

  /// Streams truck owner analytics (earnings, trips completed) filtered by active/completed status.
  Stream<TruckOwnerAnalytics> streamTruckOwnerAnalytics(String truckOwnerUid) {
    return _firestore
        .collection('loads')
        .where('assignedTruckOwnerUid', isEqualTo: truckOwnerUid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
      int completed = 0;
      int earnings = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        completed++;
        final budgetStr = data['budget'] as String? ?? '0';
        try {
          final cleanStr = budgetStr.replaceAll(RegExp(r'[^0-9]'), '');
          if (cleanStr.isNotEmpty) {
            earnings += int.parse(cleanStr);
          }
        } catch (_) {}
      }

      return TruckOwnerAnalytics(
        weeklyEarnings: earnings,
        rating: 0.0,
        completedTrips: completed,
      );
    });
  }

  /// Efficient server-side count query for total provider load count.
  Future<int> getProviderLoadCount(String providerUid) async {
    final snapshot = await _firestore
        .collection('loads')
        .where('providerUid', isEqualTo: providerUid)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Efficient server-side count query for available marketplace loads.
  Future<int> getAvailableLoadsCount() async {
    final snapshot = await _firestore
        .collection('loads')
        .where('status', isEqualTo: 'open')
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}

class TruckOwnerAnalytics {
  final int weeklyEarnings;
  final int completedTrips;
  final double rating;

  TruckOwnerAnalytics({
    required this.weeklyEarnings,
    required this.completedTrips,
    required this.rating,
  });
}

final truckOwnerAnalyticsProvider = StreamProvider.autoDispose.family<TruckOwnerAnalytics, String>((ref, uid) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(TruckOwnerAnalytics(weeklyEarnings: 0, completedTrips: 0, rating: 0.0));

  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.streamTruckOwnerAnalytics(uid).handleError((e) {
    if (kDebugMode) {
      debugPrint('STREAM ERROR: $e');
    }
  });
});
