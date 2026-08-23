import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/load_model.dart';

final loadRepositoryProvider = Provider<LoadRepository>((ref) {
  return LoadRepository(FirebaseFirestore.instance);
});

// Stream of loads for a specific load provider
final providerLoadsProvider = StreamProvider.autoDispose.family<List<LoadModel>, String>((ref, uid) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  
  final repo = ref.watch(loadRepositoryProvider);
  return repo.getProviderLoads(uid).handleError((e) {
    if (kDebugMode) {
      debugPrint('STREAM ERROR: $e');
    }
  });
});

// Stream of all open/available loads for the marketplace
final availableLoadsProvider = StreamProvider.autoDispose<List<LoadModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(loadRepositoryProvider);
  return repo.getAvailableLoads().handleError((e) {
    if (kDebugMode) {
      debugPrint('STREAM ERROR: $e');
    }
  });
});

// Stream of user load snapshots for home dashboard metrics
final userLoadsStreamProvider = StreamProvider.autoDispose.family<QuerySnapshot, String>((ref, uid) {
  final repo = ref.watch(loadRepositoryProvider);
  return repo.watchUserLoads(uid);
});

// Stream of trips assigned to a specific truck owner
final truckOwnerTripsProvider = StreamProvider.autoDispose.family<List<LoadModel>, String>((ref, uid) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(loadRepositoryProvider);
  return repo.getTruckOwnerTrips(uid).handleError((e) {
    if (kDebugMode) {
      debugPrint('STREAM ERROR: $e');
    }
  });
});

class LoadRepository {
  final FirebaseFirestore _firestore;

  LoadRepository(this._firestore);

  CollectionReference get _loads => _firestore.collection('loads');

  Stream<QuerySnapshot> watchUserLoads(String uid) {
    return _loads
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createLoad(LoadModel load) async {
    final docRef = _loads.doc();
    final newLoad = load.copyWith(loadId: docRef.id);
    await docRef.set(newLoad.toJson());
  }

  Stream<List<LoadModel>> getProviderLoads(String providerUid) {
    return _loads
        .where('providerUid', isEqualTo: providerUid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoadModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<LoadModel>> getAvailableLoads() {
    return _loads
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final loads = snapshot.docs
              .map((doc) => LoadModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          return loads.where((load) => !load.isExpired).toList();
        });
  }

  Stream<List<LoadModel>> getTruckOwnerTrips(String truckOwnerUid) {
    return _loads
        .where('assignedTruckOwnerUid', isEqualTo: truckOwnerUid)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoadModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
  
  Future<void> updateLoadStatus(String loadId, String status) async {
    await _loads.doc(loadId).update({'status': status});
  }
}

