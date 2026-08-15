import '../models/location_model.dart';

/// Abstract interface for all location services.
/// This ensures the application remains decoupled from any specific mapping vendor
/// (e.g., Mappls, Google Maps, Mapbox) and facilitates easy swapping or mocking.
abstract class LocationProvider {
  /// Searches for locations based on a text query (AutoSuggest / Autocomplete).
  Future<List<LocationModel>> searchLocations(String query);

  /// Retrieves detailed information for a specific place (e.g., coordinates, exact address)
  /// given its unique identifier from the provider.
  Future<LocationModel?> getPlaceDetails(String placeId);

  // ---------------------------------------------------------------------------
  // FUTURE CAPABILITIES
  // ---------------------------------------------------------------------------
  // The following methods are defined as part of the architecture but are NOT
  // implemented in the initial phase. They ensure the provider can scale.

  /// Returns the closest readable address/location for a given coordinate.
  Future<LocationModel?> reverseGeocode(double latitude, double longitude) {
    throw UnimplementedError('reverseGeocode is not implemented in this phase.');
  }

  /// Calculates a route between two or more locations.
  Future<dynamic> calculateRoute(LocationModel origin, LocationModel destination) {
    throw UnimplementedError('calculateRoute is not implemented in this phase.');
  }

  /// Calculates the Estimated Time of Arrival (ETA) between two coordinates.
  Future<Duration?> calculateETA(double originLat, double originLng, double destLat, double destLng) {
    throw UnimplementedError('calculateETA is not implemented in this phase.');
  }
}
