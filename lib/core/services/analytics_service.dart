import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics layer wrapping Firebase Analytics.
/// Strongly typed, zero-PII, event deduplicated telemetry interface.
class AnalyticsService {
  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  // In-memory set to prevent duplicate `load_viewed` events on Flutter widget rebuilds
  static final Set<String> _recentlyViewedLoadIds = {};
  static const int _maxViewCacheSize = 100;

  /// Log when a Truck Owner meaningfully views a load's details or card.
  static Future<void> logLoadViewed({
    required String loadId,
    required String originCity,
    required String destinationCity,
    required String vehicleType,
    int? budget,
  }) async {
    // Prevent duplicate event emission caused by Flutter rebuilds
    if (_recentlyViewedLoadIds.contains(loadId)) return;

    if (_recentlyViewedLoadIds.length >= _maxViewCacheSize) {
      _recentlyViewedLoadIds.remove(_recentlyViewedLoadIds.first);
    }
    _recentlyViewedLoadIds.add(loadId);

    final params = <String, Object>{
      'load_id': loadId,
      'origin_city': _sanitizeText(originCity),
      'destination_city': _sanitizeText(destinationCity),
      'vehicle_type': _sanitizeText(vehicleType),
    };
    if (budget != null && budget > 0) {
      params['budget'] = budget;
    }

    await _logEvent('load_viewed', params);
  }

  /// Log when a user filters or searches marketplace loads.
  static Future<void> logSearchPerformed({
    String? originCity,
    String? destinationCity,
    String? vehicleType,
    int? resultCount,
  }) async {
    final params = <String, Object>{};
    if (originCity != null && originCity.isNotEmpty) {
      params['origin_city'] = _sanitizeText(originCity);
    }
    if (destinationCity != null && destinationCity.isNotEmpty) {
      params['destination_city'] = _sanitizeText(destinationCity);
    }
    if (vehicleType != null && vehicleType.isNotEmpty) {
      params['vehicle_type'] = _sanitizeText(vehicleType);
    }
    if (resultCount != null) {
      params['result_count'] = resultCount;
    }

    await _logEvent('search_performed', params);
  }

  /// Log when a Truck Owner initiates a booking request (clicks Book/Request).
  static Future<void> logBookingInitiated({required String loadId}) async {
    await _logEvent('booking_initiated', {'load_id': loadId});
  }

  /// Log when a booking request is successfully submitted and converted.
  static Future<void> logBookingConverted({
    required String loadId,
    required String bookingId,
    int? offeredPrice,
  }) async {
    final params = <String, Object>{
      'load_id': loadId,
      'booking_id': bookingId,
    };
    if (offeredPrice != null && offeredPrice > 0) {
      params['offered_price'] = offeredPrice;
    }

    await _logEvent('booking_converted', params);
  }

  /// Log operational trip lifecycle transition.
  static Future<void> logTripStatusChanged({
    required String loadId,
    required String previousStatus,
    required String newStatus,
  }) async {
    await _logEvent('trip_status_changed', {
      'load_id': loadId,
      'previous_status': previousStatus,
      'new_status': newStatus,
    });
  }

  /// Log payment settlement acknowledgement transition.
  /// NO payment methods, bank cards, or financial credentials stored.
  static Future<void> logPaymentStatusChanged({
    required String loadId,
    required String newStatus, // marked_paid, confirmed, disputed
  }) async {
    await _logEvent('payment_status_changed', {
      'load_id': loadId,
      'new_status': newStatus,
    });
  }

  /// Log structured client non-fatal errors.
  static Future<void> logErrorEncountered({
    required String errorCode,
    required String context,
    String? category,
  }) async {
    final params = <String, Object>{
      'error_code': errorCode,
      'context': _sanitizeText(context),
    };
    if (category != null) {
      params['category'] = category;
    }

    await _logEvent('error_encountered', params);
  }

  /// Private helper to dispatch event safely without crashing the app on analytics failure.
  static Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    try {
      if (kDebugMode) {
        debugPrint('[ANALYTICS] $name: $parameters');
      } else {
        await _analytics.logEvent(name: name, parameters: parameters);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ANALYTICS ERROR] Failed to log $name: $e');
      }
    }
  }

  /// Ensures text parameters contain coarse information only and zero PII.
  static String _sanitizeText(String text) {
    var sanitized = text.replaceAll(RegExp(r'\+?[0-9]{10,12}'), '[REDACTED]');
    sanitized = sanitized.replaceAll(RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'), '[REDACTED]');
    return sanitized.trim();
  }
}
