import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_model.dart';
import 'location_provider.dart';
import 'mappls_location_provider.dart';
import 'local_json_location_provider.dart';

/// Provides the abstract LocationProvider, defaulting to Mappls.
final _primaryLocationProvider = Provider<LocationProvider>((ref) {
  return MapplsLocationProvider();
});

/// Provides the fallback offline LocationProvider.
final _fallbackLocationProvider = Provider<LocationProvider>((ref) {
  return LocalJsonLocationProvider();
});

/// Exposes the orchestrating LocationService.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(
    primaryProvider: ref.watch(_primaryLocationProvider),
    fallbackProvider: ref.watch(_fallbackLocationProvider),
  );
});

class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 15;
}

class LocationService {
  final LocationProvider primaryProvider;
  final LocationProvider fallbackProvider;

  // TTL Caches (15 minute expiration)
  final Map<String, _CacheEntry<List<LocationModel>>> _searchCache = {};
  final Map<String, _CacheEntry<LocationModel>> _detailsCache = {};

  // Rate Limiting State
  String _lastQuery = '';
  DateTime? _lastNetworkRequestTime;

  LocationService({
    required this.primaryProvider,
    required this.fallbackProvider,
  });

  /// Clears expired entries from caches
  void _cleanupCache() {
    _searchCache.removeWhere((key, entry) => entry.isExpired);
    _detailsCache.removeWhere((key, entry) => entry.isExpired);
  }

  /// Normalizes a query for caching and rate-limiting
  String _normalizeQuery(String query) {
    // Remove extra whitespace and lowercase
    return query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Future<List<LocationModel>> searchLocations(String query) async {
    final normalizedQuery = _normalizeQuery(query);

    if (normalizedQuery.isEmpty) return [];

    // Rate Limiting: Identical consecutive queries
    if (normalizedQuery == _lastQuery && _searchCache.containsKey(normalizedQuery)) {
      final entry = _searchCache[normalizedQuery]!;
      if (!entry.isExpired) {
        return entry.data;
      }
    }
    
    // Cache Check
    _cleanupCache();
    if (_searchCache.containsKey(normalizedQuery)) {
      final entry = _searchCache[normalizedQuery]!;
      if (!entry.isExpired) {
        _lastQuery = normalizedQuery;
        return entry.data;
      }
    }

    // Rate Limiting: Throttle network requests to prevent spam (e.g. fast typers despite debounce)
    final now = DateTime.now();
    if (_lastNetworkRequestTime != null && 
        now.difference(_lastNetworkRequestTime!).inMilliseconds < 200) {
      // If requests are too close, delay slightly before executing to let the debounce catch it, 
      // or just proceed. Here we'll just allow it but note it's very fast.
      // In a strict implementation, we might throw a cancellation error.
      // But debounce in UI usually handles this.
    }

    _lastQuery = normalizedQuery;
    _lastNetworkRequestTime = now;

    try {
      // Attempt Network Provider
      final results = await primaryProvider.searchLocations(query).timeout(const Duration(seconds: 10));
      _searchCache[normalizedQuery] = _CacheEntry(results);
      return results;
    } on TimeoutException {
      return _fallbackSearch(query);
    } on SocketException {
      return _fallbackSearch(query);
    } catch (e) {
      // For any other unexpected errors from Mappls SDK, fallback to ensure availability
      return _fallbackSearch(query);
    }
  }

  Future<List<LocationModel>> _fallbackSearch(String query) async {
    try {
      return await fallbackProvider.searchLocations(query);
    } catch (e) {
      return [];
    }
  }

  Future<LocationModel?> getPlaceDetails(String placeId) async {
    _cleanupCache();
    if (_detailsCache.containsKey(placeId)) {
      final entry = _detailsCache[placeId]!;
      if (!entry.isExpired) {
        return entry.data;
      }
    }

    try {
      final details = await primaryProvider.getPlaceDetails(placeId).timeout(const Duration(seconds: 10));
      if (details != null) {
        _detailsCache[placeId] = _CacheEntry(details);
        return details;
      }
      return _fallbackDetails(placeId);
    } on TimeoutException {
      return _fallbackDetails(placeId);
    } on SocketException {
      return _fallbackDetails(placeId);
    } catch (e) {
      return _fallbackDetails(placeId);
    }
  }

  Future<LocationModel?> _fallbackDetails(String placeId) async {
    try {
      return await fallbackProvider.getPlaceDetails(placeId);
    } catch (e) {
      return null;
    }
  }
}
