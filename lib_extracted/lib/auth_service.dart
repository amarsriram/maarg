import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<User?> signUp(
      String email,
      String password,
      ) async {
    UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = userCredential.user;

    if (user != null) {
      await _firestore.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "email": email,
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return user;
  }

  Future<User?> login(
      String email,
      String password,
      ) async {
    UserCredential userCredential =
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return userCredential.user;
  }
}
