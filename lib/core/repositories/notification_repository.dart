import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

final userNotificationsProvider = StreamProvider.autoDispose.family<List<NotificationModel>, String>((ref, uid) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUserNotifications(uid);
});

final unreadNotificationsCountProvider = StreamProvider.autoDispose.family<int, String>((ref, uid) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount(uid);
});

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository(this._firestore);

  CollectionReference get _notifications => _firestore.collection('notifications');

  Stream<List<NotificationModel>> getUserNotifications(String uid) {
    return _notifications
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<int> getUnreadCount(String uid) {
    return _notifications
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String uid) async {
    final snapshot = await _notifications.where('uid', isEqualTo: uid).where('isRead', isEqualTo: false).get();
    
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
