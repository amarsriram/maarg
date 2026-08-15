import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String uid; // recipient
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedLoadId;
  final String? relatedBookingId;
  final String priority;

  NotificationModel({
    required this.notificationId,
    required this.uid,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.relatedLoadId,
    this.relatedBookingId,
    this.priority = 'normal',
  });

  Map<String, dynamic> toJson() {
    return {
      'notificationId': notificationId,
      'uid': uid,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      if (relatedLoadId != null) 'relatedLoadId': relatedLoadId,
      if (relatedBookingId != null) 'relatedBookingId': relatedBookingId,
      'priority': priority,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json, String id) {
    return NotificationModel(
      notificationId: id,
      uid: json['uid'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] is Timestamp ? (json['createdAt'] as Timestamp).toDate() : DateTime.parse(json['createdAt'].toString())) 
          : DateTime.now(),
      relatedLoadId: json['relatedLoadId'],
      relatedBookingId: json['relatedBookingId'],
      priority: json['priority'] ?? 'normal',
    );
  }
}
