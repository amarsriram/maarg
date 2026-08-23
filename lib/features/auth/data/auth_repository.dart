import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_model.dart';

/// Abstract AuthRepository defining standard authentication contract.
abstract class AuthRepository {
  Future<void> ensureInitialProfile();
  Future<AppUser?> updateRole(UserRole role);
  Future<void> completeProfile({
    required String name,
    String? region,
  });
  Future<void> logout();
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Stream<DocumentSnapshot> userDocumentStream(String uid);
}

/// Firebase implementation of AuthRepository for production.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> ensureInitialProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          transaction.set(docRef, {
            'uid': user.uid,
            'role': 'none',
            'profileCompleted': false,
            'phoneNumber': user.phoneNumber,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FIRESTORE ERROR (ensureInitialProfile): $e');
      }
      rethrow;
    }
  }

  @override
  Future<AppUser?> updateRole(UserRole role) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }
    
    await _firestore.collection('users').doc(uid).set({
      'role': role.firestoreKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return AppUser(
      id: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? data['fullName'],
      role: role,
      companyName: data['companyName'],
      phoneNumber: data['phoneNumber'],
      operatingRegion: data['operatingRegion'] ?? data['region'],
      profileCompleted: data['profileCompleted'] as bool? ?? false,
    );
  }

  @override
  Future<void> completeProfile({
    required String name,
    String? region,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final data = <String, dynamic>{
      'name': name.trim(),
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (region != null && region.trim().isNotEmpty) {
      data['region'] = region.trim();
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Stream<AppUser?> authStateChanges() {
    // ── switchMap: cancels the previous inner stream on every new auth event ──
    // asyncExpand() was the previous operator. It concatenates inner streams,
    // meaning the Firestore snapshots() stream (which never completes) permanently
    // blocked the null event emitted on logout. This caused:
    //   - authStateProvider to never emit null after sign-out
    //   - GoRouter redirect to never fire
    //   - infinite logout spinner + Firestore permission-denied spam
    //
    // This manual switchMap implementation immediately cancels the previous
    // Firestore listener and emits the new event (null on logout, or a new
    // user doc stream on login/account-switch).
    final controller = StreamController<AppUser?>.broadcast();
    StreamSubscription<dynamic>? innerSub;

    final outerSub = _auth.authStateChanges().listen(
      (User? user) async {
        // Cancel the previous inner stream immediately — this is the switchMap behaviour.
        await innerSub?.cancel();
        innerSub = null;

        if (user == null) {
          // Sign-out: propagate null immediately. GoRouter will redirect to /auth.
          controller.add(null);
          return;
        }


        // Attach a fresh Firestore listener for the newly signed-in user.
        innerSub = _firestore
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen(
              (doc) {
                if (!doc.exists) {
                  // Explicitly emit null when the profile document is missing.
                  // This distinguishes a missing profile from a loading state or network error.
                  controller.add(null);
                  return;
                }

                final data = doc.data() ?? {};

                bool profileCompleted = data['profileCompleted'] as bool? ?? false;
                final String? roleStr = data['role'] as String?;
                final String normalizedRole = (roleStr ?? '').trim().toLowerCase();

                // Silent migration for supplier role.
                if (normalizedRole == 'supplier') {
                  _firestore.collection('users').doc(user.uid).set(
                    {'role': 'provider'},
                    SetOptions(merge: true),
                  );
                }

                final bool hasLegacyData =
                    (data['name'] as String?)?.trim().isNotEmpty == true ||
                    (data['fullName'] as String?)?.trim().isNotEmpty == true ||
                    (data['companyName'] as String?)?.trim().isNotEmpty == true;

                if (!profileCompleted && roleStr != null && roleStr != 'none' && hasLegacyData) {
                  _firestore.collection('users').doc(user.uid).set(
                    {'profileCompleted': true},
                    SetOptions(merge: true),
                  );
                  profileCompleted = true; // Optimistic update
                }

                final appUser = AppUser(
                  id: user.uid,
                  email: user.email ?? '',
                  name: data['name'] ?? data['fullName'],
                  role: _roleFromString(roleStr),
                  companyName: data['companyName'],
                  phoneNumber: data['phoneNumber'],
                  operatingRegion: data['operatingRegion'] ?? data['region'],
                  profileCompleted: profileCompleted,
                );
                controller.add(appUser);
              },
              onError: (Object error) {
                if (kDebugMode) {
                  debugPrint('FIRESTORE ERROR (authStateChanges): $error');
                }
                // Do NOT add to controller — avoids crashing authStateProvider.
                // The stream simply stops updating until the condition resolves.
              },
            );
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('FIREBASE AUTH ERROR: $error');
        }
        controller.addError(error);
      },
    );

    // Clean up both subscriptions when the returned stream is cancelled
    // (e.g. when Riverpod disposes authStateProvider on app exit).
    controller.onCancel = () async {
      await innerSub?.cancel();
      await outerSub.cancel();
    };

    return controller.stream;
  }

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email,
      role: UserRole.none,
      profileCompleted: false,
    );
  }

  void dispose() {}

  @override
  Stream<DocumentSnapshot> userDocumentStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }
}

UserRole _roleFromString(String? roleStr) {
  final String normalized = (roleStr ?? '').trim().toLowerCase();

  UserRole parsedRole;
  switch (normalized) {
    case 'provider':
    case 'supplier':
    case 'loadprovider':
    case 'load provider':
      parsedRole = UserRole.provider;
      break;

    case 'truckowner':
    case 'truck_owner':
    case 'truck owner':
    case 'driver':
      parsedRole = UserRole.truckOwner;
      break;

    default:
      parsedRole = UserRole.none;
  }

  return parsedRole;
}

// Riverpod Provider for User Document Stream
final userDocumentStreamProvider = StreamProvider.autoDispose.family<DocumentSnapshot, String>((ref, uid) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.userDocumentStream(uid);
});

// Riverpod Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = FirebaseAuthRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

// Riverpod Provider for Auth State Changes Stream
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});
