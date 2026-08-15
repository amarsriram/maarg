import 'package:flutter/foundation.dart';
import 'package:mappls_gl/mappls_gl.dart';
import '../models/location_model.dart';
import 'location_provider.dart';

/// Concrete implementation of [LocationProvider] using the official Mappls SDK.
/// This class is strictly isolated. Only this class knows about Mappls-specific models.
class MapplsLocationProvider extends LocationProvider {
  @override
  Future<List<LocationModel>> searchLocations(String query) async {
    try {
      final response = await MapplsAutoSuggest(
        query: query,
        tokenizeAddress: true,
      ).callAutoSuggest();

      if (response != null && response.suggestedLocations != null) {
        return response.suggestedLocations!.map((eLocation) => _mapToLocationModel(eLocation)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('MapplsLocationProvider AutoSuggest Error: $e');
      // Rethrow to let the service layer handle fallback
      rethrow;
    }
  }

  @override
  Future<LocationModel?> getPlaceDetails(String placeId) async {
    try {
      // NOTE: Using Mappls Pin / eLoc for place details.
      // ELocation (from autosuggest) usually provides mapplsPin.
      final response = await MapplsPlaceDetail(
        mapplsPin: placeId,
      ).callPlaceDetail();

      if (response != null) {
        // Place details might not return a list or we take the first item if it does.
        // Mappls API generally returns place details for the specific pin.
        return LocationModel(
          id: placeId,
          displayName: response.placeName ?? response.address ?? 'Unknown Location',
          state: response.state ?? '',
          district: response.district ?? '',
          city: response.city ?? '',
          locality: response.locality,
          latitude: response.latitude,
          longitude: response.longitude,
        );
      }
      return null;
    } catch (e) {
      debugPrint('MapplsLocationProvider PlaceDetail Error: $e');
      rethrow;
    }
  }

  /// Maps a Mappls [ELocation] to our domain [LocationModel].
  LocationModel _mapToLocationModel(ELocation eLocation) {
    // Fallbacks for display string
    String display = eLocation.placeName ?? '';
    if (display.isEmpty && eLocation.placeAddress != null) {
      display = eLocation.placeAddress!;
    }
    
    // AddressTokens are sometimes populated if tokenizeAddress=true
    final tokens = eLocation.addressTokens;
    final state = tokens?.state ?? '';
    final district = tokens?.district ?? '';
    final city = tokens?.city ?? '';
    final locality = tokens?.locality;

    return LocationModel(
      id: eLocation.mapplsPin ?? '',
      displayName: display.isNotEmpty ? display : 'Unknown Location',
      state: state,
      district: district,
      city: city,
      locality: locality,
      // Mappls AutoSuggest might not return lat/lng, usually requires PlaceDetail call
      latitude: eLocation.latitude,
      longitude: eLocation.longitude,
    );
  }
}
