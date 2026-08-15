import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_status.dart';

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
  final String? assignedTruckOwnerUid;
  final String? assignedTruckOwnerName;
  final DateTime createdAt;
  final DateTime updatedAt;

  TripStatus get tripStatus => TripStatusExtension.fromString(status);

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
      if (assignedTruckOwnerUid != null) 'assignedTruckOwnerUid': assignedTruckOwnerUid,
      if (assignedTruckOwnerName != null) 'assignedTruckOwnerName': assignedTruckOwnerName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
