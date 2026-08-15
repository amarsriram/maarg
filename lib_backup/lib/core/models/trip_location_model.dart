class TripLocationModel {
  final String locationId;
  final String tripId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double heading;
  final double speed;

  TripLocationModel({
    required this.locationId,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.heading,
    required this.speed,
  });

  Map<String, dynamic> toMap() {
    return {
      'locationId': locationId,
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'heading': heading,
      'speed': speed,
    };
  }

  factory TripLocationModel.fromMap(Map<String, dynamic> map, String id) {
    return TripLocationModel(
      locationId: id,
      tripId: map['tripId'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
