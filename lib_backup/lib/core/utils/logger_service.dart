import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final loggerProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});

class LoggerService {
  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        '\x1B[34m[DEBUG]\x1B[0m ${tag != null ? '[$tag] ' : ''}$message',
        name: 'Maarg',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void info(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(
        '\x1B[32m[INFO]\x1B[0m ${tag != null ? '[$tag] ' : ''}$message',
        name: 'Maarg',
      );
    }
  }

  void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        '\x1B[33m[WARNING]\x1B[0m ${tag != null ? '[$tag] ' : ''}$message',
        name: 'Maarg',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        '\x1B[31m[ERROR]\x1B[0m ${tag != null ? '[$tag] ' : ''}$message',
        name: 'Maarg',
        error: error,
        stackTrace: stackTrace,
      );
    }
    // TODO: In production, send to Crashlytics or similar service
  }

  void transaction(String name, String status) {
    if (kDebugMode) {
      developer.log(
        '\x1B[35m[TRANSACTION]\x1B[0m [$name] -> $status',
        name: 'Maarg',
      );
    }
  }
}
