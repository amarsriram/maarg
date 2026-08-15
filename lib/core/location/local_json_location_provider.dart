import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/location_model.dart';
import 'location_provider.dart';

/// Concrete implementation of [LocationProvider] that searches local JSON assets.
/// Used primarily as an offline fallback when network location services are unavailable.
class LocalJsonLocationProvider extends LocationProvider {
  List<LocationModel>? _cachedLocations;

  Future<void> _ensureLoaded() async {
    if (_cachedLocations != null) return;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/india_locations.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedLocations = jsonList.map((e) => LocationModel.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _cachedLocations = [];
    }
  }

  @override
  Future<List<LocationModel>> searchLocations(String query) async {
    await _ensureLoaded();
    
    if (query.trim().isEmpty) {
      return _cachedLocations ?? [];
    }

    final lowerQuery = query.toLowerCase().trim();
    return _cachedLocations!.where((loc) {
      return loc.displayName.toLowerCase().contains(lowerQuery) ||
             loc.city.toLowerCase().contains(lowerQuery) ||
             loc.state.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Future<LocationModel?> getPlaceDetails(String placeId) async {
    await _ensureLoaded();
    
    try {
      return _cachedLocations!.firstWhere((loc) => loc.id == placeId);
    } catch (e) {
      return null;
    }
  }
}
