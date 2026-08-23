import 'package:cloud_firestore/cloud_firestore.dart';

class ContactExchangeModel {
  final String bookingId;
  final String loadId;
  final String truckOwnerUid;
  final String truckOwnerPhone;
  final String providerUid;
  final String? providerPhone;
  final String status;
  final DateTime? unlockedAt;

  ContactExchangeModel({
    required this.bookingId,
    required this.loadId,
    required this.truckOwnerUid,
    required this.truckOwnerPhone,
    required this.providerUid,
    this.providerPhone,
    required this.status,
    this.unlockedAt,
  });

  factory ContactExchangeModel.fromJson(Map<String, dynamic> json, String id) {
    return ContactExchangeModel(
      bookingId: id,
      loadId: json['loadId'] ?? '',
      truckOwnerUid: json['truckOwnerUid'] ?? '',
      truckOwnerPhone: json['truckOwnerPhone'] ?? '',
      providerUid: json['providerUid'] ?? '',
      providerPhone: json['providerPhone'],
      status: json['status'] ?? 'pending',
      unlockedAt: (json['unlockedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'loadId': loadId,
      'truckOwnerUid': truckOwnerUid,
      'truckOwnerPhone': truckOwnerPhone,
      'providerUid': providerUid,
      if (providerPhone != null) 'providerPhone': providerPhone,
      'status': status,
      if (unlockedAt != null) 'unlockedAt': Timestamp.fromDate(unlockedAt!),
    };
  }
}
