import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_model.dart';

/// Abstract AuthRepository defining standard authentication contract.
abstract class AuthRepository {
  Future<AppUser?> login(String email, String password);
  Future<AppUser?> register(String email, String password);
  Future<AppUser?> updateRole(UserRole role);
  Future<void> logout();
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
}

/// Firebase implementation of AuthRepository for production.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<AppUser?> login(String email, String password) async {
    final UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    
    bool profileCompleted = data['profileCompleted'] as bool? ?? false;
    final String? roleStr = data['role'] as String?;
    final String normalizedRole = (roleStr ?? '').trim().toLowerCase();

    // Silent migration for supplier role
    if (normalizedRole == 'supplier') {
      await _firestore.collection('users').doc(uid).set(
        {'role': 'provider'},
        SetOptions(merge: true),
      );
    }
    
    final bool hasLegacyData = (data['name'] as String?)?.trim().isNotEmpty == true || 
                               (data['fullName'] as String?)?.trim().isNotEmpty == true ||
                               (data['companyName'] as String?)?.trim().isNotEmpty == true;
    
    // Silent migration for legacy existing users only
    if (!profileCompleted && roleStr != null && roleStr != 'none' && hasLegacyData) {
      await _firestore.collection('users').doc(uid).set(
        {'profileCompleted': true},
        SetOptions(merge: true),
      );
      profileCompleted = true;
    }

    return AppUser(
      id: uid,
      email: email,
      name: data['name'] ?? data['fullName'],
      role: _roleFromString(roleStr),
      companyName: data['companyName'],
      phoneNumber: data['phoneNumber'],
      operatingRegion: data['operatingRegion'] ?? data['region'],
      profileCompleted: profileCompleted,
    );
  }

  @override
  Future<AppUser?> register(String email, String password) async {
    final UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user?.uid;
    if (uid == null) return null;
    final user = AppUser(
      id: uid,
      email: email,
      role: UserRole.none,
      profileCompleted: false,
    );
    debugPrint('CREATING USER DOC...');
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'role': null,
      'profileCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('USER DOC CREATED');
    return user;
  }

  @override
  Future<AppUser?> updateRole(UserRole role) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint("UID IS NULL IN UPDATEROLE");
      return null;
    }
    
    debugPrint("ROLE SAVE START");
    await _firestore.collection('users').doc(uid).set({
      'role': role.firestoreKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint("ROLE SAVE SUCCESS");
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
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncExpand((User? user) {
      if (user == null) {
        return Stream.value(null);
      }
      debugPrint('AUTH UID: ${FirebaseAuth.instance.currentUser?.uid}');
      debugPrint('READING DOC UID: ${user.uid}');
      
      // Listen to Firestore document changes for this user
      return _firestore.collection('users').doc(user.uid).snapshots().handleError((error) {
        debugPrint('FIRESTORE ERROR (authStateChanges): $error');
      }).where((doc) {
        if (!doc.exists) debugPrint('WAITING FOR USER DOC TO BE CREATED...');
        return doc.exists;
      }).map((doc) {
        debugPrint('DOC EXISTS: ${doc.exists}');
        debugPrint('DOC DATA: ${doc.data()}');
        
        final data = doc.data() ?? {};
        
        bool profileCompleted = data['profileCompleted'] as bool? ?? false;
        final String? roleStr = data['role'] as String?;
        final String normalizedRole = (roleStr ?? '').trim().toLowerCase();

        // Silent migration for supplier role
        if (normalizedRole == 'supplier') {
          _firestore.collection('users').doc(user.uid).set(
            {'role': 'provider'},
            SetOptions(merge: true),
          );
        }

        final bool hasLegacyData = (data['name'] as String?)?.trim().isNotEmpty == true || 
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
        debugPrint('USER ROLE: ${appUser.role}');
        debugPrint('PROFILE COMPLETE: ${appUser.profileCompleted}');
        return appUser;
      });
    });
  }

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      role: UserRole.none,
      profileCompleted: false,
    );
  }

  void dispose() {}
}

UserRole _roleFromString(String? roleStr) {
  final String normalized = (roleStr ?? '').trim().toLowerCase();
  debugPrint('ROLE PARSE: raw="$roleStr" normalized="$normalized"');

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

  debugPrint('PARSED ROLE => $parsedRole');
  return parsedRole;
}

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
