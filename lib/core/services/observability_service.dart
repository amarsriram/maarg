import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for application observability, non-fatal reporting,
/// and crash tracking via Firebase Crashlytics.
class ObservabilityService {
  static FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  /// Initializes global error handlers for Flutter framework and async errors.
  static void initialize() {
    // Pass all uncaught Flutter framework errors to Crashlytics
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (!kDebugMode) {
        _crashlytics.recordFlutterFatalError(details);
      }
    };

    // Pass all uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('UNCAUGHT ASYNC ERROR: $error\n$stack');
      } else {
        _crashlytics.recordError(error, stack, fatal: true);
      }
      return true;
    };
  }

  /// Reports a non-fatal operational failure with a structured error code.
  /// PRIVACY RULE: Never include PII (phone numbers, emails, passwords, OTPs,
  /// full names, bank details) in [context] or [reason].
  static Future<void> reportNonFatalError({
    required String errorCode,
    required dynamic exception,
    StackTrace? stackTrace,
    String? context,
  }) async {
    final sanitizedContext = context != null ? _sanitizeString(context) : 'unknown';
    final sanitizedExceptionMessage = _sanitizeString(exception.toString());

    if (kDebugMode) {
      debugPrint('[OBSERVABILITY] Non-fatal error [$errorCode] in $sanitizedContext: $sanitizedExceptionMessage');
    } else {
      await _crashlytics.log('ErrorCode: $errorCode | Context: $sanitizedContext');
      await _crashlytics.recordError(
        exception,
        stackTrace,
        reason: 'NonFatal: $errorCode ($sanitizedContext)',
        fatal: false,
      );
    }
  }

  /// Sanitizes string inputs to prevent accidental PII leakage into telemetry.
  static String _sanitizeString(String input) {
    // Strip phone numbers (+91..., 10-digit numbers)
    var sanitized = input.replaceAll(RegExp(r'\+?[0-9]{10,12}'), '[REDACTED_PHONE]');
    // Strip email addresses
    sanitized = sanitized.replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '[REDACTED_EMAIL]');
    return sanitized;
  }
}
