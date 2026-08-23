import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'firebase_options.dart';

import 'package:flutter/foundation.dart';
import 'package:maarg/app/app.dart';
import 'package:maarg/core/services/observability_service.dart';
import 'package:maarg/core/services/app_check_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize App Check attestation
  await AppCheckService.initialize();

  // Initialize Crashlytics & global observability handlers
  ObservabilityService.initialize();

  // Explicit development-only toggle for local Firebase Emulator testing.
  // Can be activated via --dart-define=USE_EMULATOR=true
  // Must be true AND app must be in debug mode to activate.
  const bool useFirebaseEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  
  if (kDebugMode && useFirebaseEmulator) {
    // 10.0.2.2 is the special IP alias that allows the Android Emulator
    // to connect to the Windows host's localhost (127.0.0.1).
    FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    debugPrint('Connected to Firebase Emulators (Auth, Firestore) at 10.0.2.2');
  }

  // Phase 5: Global error handling
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Something went wrong',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: MaargApp()));
}


