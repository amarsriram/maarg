import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/repositories/notification_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';

class NotificationFeedScreen extends ConsumerWidget {
  const NotificationFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final userState = ref.watch(authStateProvider);
    final uid = userState.value?.id;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    final notificationsAsync = ref.watch(userNotificationsProvider(uid));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () {
              ref.read(notificationRepositoryProvider).markAllAsRead(uid);
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                isDark: isDark,
                onTap: () {
                  String? targetRoute;
                  if (notification.type == 'NEW_BOOKING_REQUEST') {
                    targetRoute = '/provider-dashboard?tab=2';
                  } else if (notification.type == 'BOOKING_ACCEPTED') {
                    targetRoute = '/truck-owner-dashboard?tab=2';
                  } else if (notification.type == 'TRIP_STATUS_UPDATE' || notification.type == 'TRIP_COMPLETED') {
                    if (userState.value?.role == UserRole.provider) {
                      targetRoute = '/provider-dashboard?tab=2';
                    } else {
                      targetRoute = '/truck-owner-dashboard?tab=2';
                    }
                  } else if (notification.type == 'BOOKING_REJECTED') {
                    targetRoute = '/truck-owner-dashboard?tab=1';
                  } else if (notification.type == 'BOOKING_WITHDRAWN') {
                    targetRoute = '/provider-dashboard?tab=2';
                  }

                  if (targetRoute != null && context.mounted) {
                    debugPrint('NOTIFICATION TAP');
                    debugPrint('TYPE=${notification.type}');
                    debugPrint('TARGET=$targetRoute');
                    context.go(targetRoute);
                  }

                  if (!notification.isRead) {
                    unawaited(ref.read(notificationRepositoryProvider).markAsRead(notification.notificationId));
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading notifications: $err')),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final bool isDark;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final unreadColor = AppColors.primaryBlue.withValues(alpha: 0.1);

    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'NEW_BOOKING_REQUEST':
        icon = Icons.assignment_late_outlined;
        iconColor = AppColors.warning;
        break;
      case 'BOOKING_ACCEPTED':
        icon = Icons.check_circle_outline;
        iconColor = AppColors.success;
        break;
      case 'BOOKING_REJECTED':
        icon = Icons.cancel_outlined;
        iconColor = AppColors.error;
        break;
      case 'TRIP_STATUS_UPDATE':
        if (notification.message.toLowerCase().contains('delivered')) {
          icon = Icons.check_circle_rounded;
          iconColor = AppColors.success;
        } else {
          icon = Icons.local_shipping_outlined;
          iconColor = AppColors.primaryBlue;
        }
        break;
      case 'TRIP_COMPLETED':
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.success;
        break;
      case 'DELAY':
        icon = Icons.timer_outlined;
        iconColor = AppColors.warning;
        break;
      case 'DISPUTE':
        icon = Icons.warning_rounded;
        iconColor = AppColors.error;
        break;
      case 'BOOKING_WITHDRAWN':
        icon = Icons.undo_rounded;
        iconColor = AppColors.warning;
        break;
      default:
        icon = Icons.notifications_none;
        iconColor = AppColors.primaryBlue;
    }

    if (notification.priority == 'high') {
      iconColor = AppColors.error;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? bgColor : unreadColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead ? borderColor : AppColors.primaryBlue.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimeAgo(notification.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 1) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Just now';
  }
}
