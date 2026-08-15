import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_status.dart';
import 'location_model.dart';

class LoadModel {
  final String loadId;
  final String providerUid;
  final String providerName;
  final String pickupLocation;
  final String dropLocation;
  final String materialType;
  final String truckType;
  final String weight;
  final String budget;
  final String pickupDate;
  final String? notes;
  final String status;
  final LocationModel? pickupLocationDetails;
  final LocationModel? dropLocationDetails;
  final String? assignedTruckOwnerUid;
  final String? assignedTruckOwnerName;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isExpired {
    final statusEnum = TripStatusExtension.fromString(status);
    if (statusEnum != TripStatus.open && statusEnum != TripStatus.requested) return false;
    try {
      final date = DateTime.parse(pickupDate);
      return date.isBefore(DateTime.now());
    } catch (_) {
      // Legacy unparseable string formats won't auto-expire
      return false;
    }
  }

  TripStatus get tripStatus {
    if (isExpired) return TripStatus.expired;
    return TripStatusExtension.fromString(status);
  }

  LoadModel({
    required this.loadId,
    required this.providerUid,
    required this.providerName,
    required this.pickupLocation,
    required this.dropLocation,
    required this.materialType,
    required this.truckType,
    required this.weight,
    required this.budget,
    required this.pickupDate,
    this.notes,
    required this.status,
    this.pickupLocationDetails,
    this.dropLocationDetails,
    this.assignedTruckOwnerUid,
    this.assignedTruckOwnerName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoadModel.fromJson(Map<String, dynamic> json, String id) {
    return LoadModel(
      loadId: id,
      providerUid: json['providerUid'] ?? '',
      providerName: json['providerName'] ?? '',
      pickupLocation: json['pickupLocation'] ?? '',
      dropLocation: json['dropLocation'] ?? '',
      materialType: json['materialType'] ?? '',
      truckType: json['truckType'] ?? '',
      weight: json['weight'] ?? '',
      budget: json['budget'] ?? '',
      pickupDate: json['pickupDate'] ?? '',
      notes: json['notes'],
      status: json['status'] ?? 'open',
      pickupLocationDetails: json['pickupLocationDetails'] != null ? LocationModel.fromMap(json['pickupLocationDetails'] as Map<String, dynamic>) : null,
      dropLocationDetails: json['dropLocationDetails'] != null ? LocationModel.fromMap(json['dropLocationDetails'] as Map<String, dynamic>) : null,
      assignedTruckOwnerUid: json['assignedTruckOwnerUid'],
      assignedTruckOwnerName: json['assignedTruckOwnerName'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providerUid': providerUid,
      'providerName': providerName,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'materialType': materialType,
      'truckType': truckType,
      'weight': weight,
      'budget': budget,
      'pickupDate': pickupDate,
      'notes': notes,
      'status': status,
      if (pickupLocationDetails != null) 'pickupLocationDetails': pickupLocationDetails!.toMap(),
      if (dropLocationDetails != null) 'dropLocationDetails': dropLocationDetails!.toMap(),
      if (assignedTruckOwnerUid != null) 'assignedTruckOwnerUid': assignedTruckOwnerUid,
      if (assignedTruckOwnerName != null) 'assignedTruckOwnerName': assignedTruckOwnerName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LoadModel copyWith({
    String? loadId,
    String? providerUid,
    String? providerName,
    String? pickupLocation,
    String? dropLocation,
    String? materialType,
    String? truckType,
    String? weight,
    String? budget,
    String? pickupDate,
    String? notes,
    String? status,
    LocationModel? pickupLocationDetails,
    LocationModel? dropLocationDetails,
    String? assignedTruckOwnerUid,
    String? assignedTruckOwnerName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LoadModel(
      loadId: loadId ?? this.loadId,
      providerUid: providerUid ?? this.providerUid,
      providerName: providerName ?? this.providerName,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      materialType: materialType ?? this.materialType,
      truckType: truckType ?? this.truckType,
      weight: weight ?? this.weight,
      budget: budget ?? this.budget,
      pickupDate: pickupDate ?? this.pickupDate,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      pickupLocationDetails: pickupLocationDetails ?? this.pickupLocationDetails,
      dropLocationDetails: dropLocationDetails ?? this.dropLocationDetails,
      assignedTruckOwnerUid: assignedTruckOwnerUid ?? this.assignedTruckOwnerUid,
      assignedTruckOwnerName: assignedTruckOwnerName ?? this.assignedTruckOwnerName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
