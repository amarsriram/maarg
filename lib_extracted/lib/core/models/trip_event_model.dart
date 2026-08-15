class TripEventModel {
  final String eventId;
  final String tripId; // same as loadId
  final String loadId;
  final String eventType;
  final String message;
  final String actorUid;
  final String actorName;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  TripEventModel({
    required this.eventId,
    required this.tripId,
    required this.loadId,
    required this.eventType,
    required this.message,
    required this.actorUid,
    required this.actorName,
    required this.createdAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'tripId': tripId,
      'loadId': loadId,
      'eventType': eventType,
      'message': message,
      'actorUid': actorUid,
      'actorName': actorName,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory TripEventModel.fromJson(Map<String, dynamic> json, String id) {
    return TripEventModel(
      eventId: id,
      tripId: json['tripId'] ?? '',
      loadId: json['loadId'] ?? '',
      eventType: json['eventType'] ?? '',
      message: json['message'] ?? '',
      actorUid: json['actorUid'] ?? '',
      actorName: json['actorName'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : {},
    );
  }
}
