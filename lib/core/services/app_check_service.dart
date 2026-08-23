import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for initializing Firebase App Check.
/// Distinguishes Debug vs Release providers cleanly without hardcoding tokens or secrets.
class AppCheckService {
  /// Initializes Firebase App Check with platform-specific attestation providers.
  /// - Android Release: AndroidPlayIntegrityProvider
  /// - Android Debug: AndroidDebugProvider (generates local debug token in logcat)
  /// - Apple Release: AppleDeviceCheckProvider
  /// - Apple Debug: AppleDebugProvider
  static Future<void> initialize() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? const AppleDebugProvider() : const AppleDeviceCheckProvider(),
      );
      if (kDebugMode) {
        debugPrint('[APP_CHECK] Initialized in DEBUG mode using AndroidDebugProvider');
      } else {
        debugPrint('[APP_CHECK] Initialized in RELEASE mode using AndroidPlayIntegrityProvider');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[APP_CHECK ERROR] App Check initialization failed: $e');
      }
    }
  }
}
