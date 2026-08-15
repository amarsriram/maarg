import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/trip_event_model.dart';

final tripEventRepositoryProvider = Provider<TripEventRepository>((ref) {
  return TripEventRepository(FirebaseFirestore.instance);
});

final tripEventsProvider = StreamProvider.autoDispose.family<List<TripEventModel>, String>((ref, loadId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(tripEventRepositoryProvider);
  return repo.getEventsForTrip(loadId).handleError((e) {
    if (kDebugMode) {
      debugPrint('STREAM ERROR: $e');
    }
  });
});

class TripEventRepository {
  final FirebaseFirestore _firestore;

  TripEventRepository(this._firestore);

  CollectionReference get _events => _firestore.collection('tripEvents');

  Stream<List<TripEventModel>> getEventsForTrip(String loadId) {
    return _events
        .where('loadId', isEqualTo: loadId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripEventModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
}
