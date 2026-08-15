import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/trip_location_model.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(FirebaseFirestore.instance);
});

final tripLocationStreamProvider = StreamProvider.autoDispose.family<TripLocationModel?, String>((ref, tripId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(locationRepositoryProvider);
  return repo.streamLatestLocation(tripId).handleError((e) {
    debugPrint('STREAM ERROR: $e');
  });
});

class LocationRepository {
  final FirebaseFirestore _firestore;

  LocationRepository(this._firestore);

  /// Push a location update to Firestore
  Future<void> updateLocation(TripLocationModel location) async {
    try {
      await _firestore
          .collection('trips')
          .doc(location.tripId)
          .collection('locations')
          .doc(location.locationId)
          .set(location.toMap());
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  /// Stream the latest location for a specific trip
  Stream<TripLocationModel?> streamLatestLocation(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('locations')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return TripLocationModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    });
  }
}
