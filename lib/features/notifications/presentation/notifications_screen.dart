import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/repositories/notification_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authStateProvider);
    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final user = authState.value;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final notifsStream = ref.watch(userNotificationsProvider(user.id));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          _MarkAllReadButton(userId: user.id),
        ],
      ),
      body: notifsStream.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return InkWell(
                onTap: () {
                  String? targetRoute;
                  if (notif.type == 'NEW_BOOKING_REQUEST') {
                    targetRoute = '/provider-dashboard?tab=2';
                  } else if (notif.type == 'BOOKING_ACCEPTED') {
                    targetRoute = '/truck-owner-dashboard?tab=2';
                  } else if (notif.type == 'TRIP_STATUS_UPDATE' || notif.type == 'TRIP_COMPLETED') {
                    if (user.role == UserRole.provider) {
                      targetRoute = '/provider-dashboard?tab=2';
                    } else {
                      targetRoute = '/truck-owner-dashboard?tab=2';
                    }
                  } else if (notif.type == 'BOOKING_REJECTED') {
                    targetRoute = '/truck-owner-dashboard?tab=1';
                  } else if (notif.type == 'BOOKING_WITHDRAWN') {
                    targetRoute = '/provider-dashboard?tab=2';
                  }

                  if (targetRoute != null && context.mounted) {
                    debugPrint('NOTIFICATION TAP');
                    debugPrint('TYPE=${notif.type}');
                    debugPrint('TARGET=$targetRoute');
                    context.go(targetRoute);
                  }

                  if (!notif.isRead) {
                    unawaited(ref.read(notificationRepositoryProvider).markAsRead(notif.notificationId));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: notif.isRead 
                        ? (isDark ? AppColors.darkSurface : Colors.white)
                        : (isDark ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.primaryBlue.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: notif.isRead 
                          ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                          : AppColors.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: notif.isRead 
                              ? (isDark ? AppColors.darkBg : AppColors.lightBg)
                              : AppColors.primaryBlue.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          size: 20,
                          color: notif.isRead 
                              ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
                              : AppColors.primaryBlue,
                        ),
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
                                    notif.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatTimeAgo(notif.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif.message,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Just now';
  }
}

class _MarkAllReadButton extends ConsumerStatefulWidget {
  final String userId;
  const _MarkAllReadButton({required this.userId});

  @override
  ConsumerState<_MarkAllReadButton> createState() => _MarkAllReadButtonState();
}

class _MarkAllReadButtonState extends ConsumerState<_MarkAllReadButton> {
  bool _isLoading = false;

  Future<void> _handleMarkAllRead() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead(widget.userId).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waiting for internet connection...\nYour action will continue automatically when connected.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        if (e.code == 'unavailable') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection. Please reconnect and try again.'), backgroundColor: AppColors.error),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${e.message ?? e.toString()}'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark all as read.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return TextButton(
      onPressed: _handleMarkAllRead,
      child: const Text('Mark all read', style: TextStyle(color: AppColors.primaryBlue)),
    );
  }
}
