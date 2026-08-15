import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String bookingId;
  final String loadId;
  final String providerUid;
  final String truckOwnerUid;
  final String truckOwnerName;
  final String pickupLocation;
  final String dropLocation;
  final String budget;
  final String status;
  final DateTime createdAt;

  BookingModel({
    required this.bookingId,
    required this.loadId,
    required this.providerUid,
    required this.truckOwnerUid,
    required this.truckOwnerName,
    required this.pickupLocation,
    required this.dropLocation,
    required this.budget,
    required this.status,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json, String id) {
    return BookingModel(
      bookingId: id,
      loadId: json['loadId'] ?? '',
      providerUid: json['providerUid'] ?? '',
      truckOwnerUid: json['truckOwnerUid'] ?? '',
      truckOwnerName: json['truckOwnerName'] ?? '',
      pickupLocation: json['pickupLocation'] ?? '',
      dropLocation: json['dropLocation'] ?? '',
      budget: json['budget'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loadId': loadId,
      'providerUid': providerUid,
      'truckOwnerUid': truckOwnerUid,
      'truckOwnerName': truckOwnerName,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'budget': budget,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
