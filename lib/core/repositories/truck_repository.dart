import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final truckRepositoryProvider = Provider<TruckRepository>((ref) {
  return TruckRepository(FirebaseFirestore.instance);
});

final availableTrucksStreamProvider = StreamProvider.autoDispose<QuerySnapshot>((ref) {
  final repo = ref.watch(truckRepositoryProvider);
  return repo.watchAvailableTrucks();
});

class TruckRepository {
  final FirebaseFirestore _firestore;

  TruckRepository(this._firestore);

  Stream<QuerySnapshot> watchAvailableTrucks() {
    return _firestore.collection('trucks').snapshots();
  }
}
