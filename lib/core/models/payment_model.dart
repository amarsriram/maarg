import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String paymentId;
  final String loadId;
  final String providerUid;
  final String truckOwnerUid;
  final String amount;
  final String currency;
  final String status;
  final DateTime? markedPaidAt;
  final String? markedPaidBy;
  final DateTime? confirmedAt;
  final String? confirmedBy;
  final DateTime? disputedAt;
  final String? disputedBy;

  PaymentModel({
    required this.paymentId,
    required this.loadId,
    required this.providerUid,
    required this.truckOwnerUid,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.markedPaidAt,
    this.markedPaidBy,
    this.confirmedAt,
    this.confirmedBy,
    this.disputedAt,
    this.disputedBy,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json, String id) {
    return PaymentModel(
      paymentId: id,
      loadId: json['loadId'] ?? '',
      providerUid: json['providerUid'] ?? '',
      truckOwnerUid: json['truckOwnerUid'] ?? '',
      amount: json['amount'] ?? '',
      currency: json['currency'] ?? 'INR',
      status: json['status'] ?? 'pending',
      markedPaidAt: _parseTimestamp(json['markedPaidAt']),
      markedPaidBy: json['markedPaidBy'],
      confirmedAt: _parseTimestamp(json['confirmedAt']),
      confirmedBy: json['confirmedBy'],
      disputedAt: _parseTimestamp(json['disputedAt']),
      disputedBy: json['disputedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loadId': loadId,
      'providerUid': providerUid,
      'truckOwnerUid': truckOwnerUid,
      'amount': amount,
      'currency': currency,
      'status': status,
      if (markedPaidAt != null) 'markedPaidAt': Timestamp.fromDate(markedPaidAt!),
      if (markedPaidBy != null) 'markedPaidBy': markedPaidBy,
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
      if (confirmedBy != null) 'confirmedBy': confirmedBy,
      if (disputedAt != null) 'disputedAt': Timestamp.fromDate(disputedAt!),
      if (disputedBy != null) 'disputedBy': disputedBy,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool canTransitionTo(String nextStatus) {
    switch (status) {
      case 'pending':
        return nextStatus == 'marked_paid';
      case 'marked_paid':
        return nextStatus == 'confirmed' || nextStatus == 'disputed';
      case 'confirmed':
        return false;
      case 'disputed':
        return false;
      default:
        return false;
    }
  }
}

