class LocationModel {
  final String id;
  final String displayName;
  final String state;
  final String district;
  final String city;
  final String? locality;
  final double? latitude;
  final double? longitude;

  const LocationModel({
    required this.id,
    required this.displayName,
    required this.state,
    required this.district,
    required this.city,
    this.locality,
    this.latitude,
    this.longitude,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      state: map['state'] as String? ?? '',
      district: map['district'] as String? ?? '',
      city: map['city'] as String? ?? '',
      locality: map['locality'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'state': state,
      'district': district,
      'city': city,
      if (locality != null) 'locality': locality,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}
