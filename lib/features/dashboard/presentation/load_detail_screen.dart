import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/repositories/contact_exchange_repository.dart';
import '../../../../core/repositories/trip_event_repository.dart';
import '../../../../core/repositories/payment_repository.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/services/trip_operations_service.dart';
import '../../../../core/utils/load_formatters.dart';
import '../../../../core/widgets/contact_exchange_card.dart';
import '../../../../core/widgets/payment_status_card.dart';
import '../../../../core/widgets/rich_location_card.dart';
import '../../auth/data/auth_repository.dart';
import '../../trip/presentation/widgets/trip_progress_timeline.dart';
import '../../../../core/models/trip_status.dart';
import '../../../../core/services/analytics_service.dart';

class LoadDetailScreen extends ConsumerWidget {
  const LoadDetailScreen({super.key, required this.loadId, required this.initialLoad});

  final String loadId;
  final LoadModel initialLoad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // To make it truly live, we should listen to the specific load.
    // Assuming we have a stream for a specific load, but we might not have one yet.
    // For now, we just display the static initialLoad, and later we could connect a stream.
    // Or we can just watch the providerLoadsProvider or availableLoadsProvider and find it.
    // For robust architecture, let's just use initialLoad and assume it's updated when they go back.
    // If the user wants a LIVE command center, we should add a loadProvider for single load.

    final authState = ref.watch(authStateProvider);
    
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final user = authState.value;
    
    if (user == null) {
      return const SizedBox.shrink();
    }

    final isProviderFallback = user.id == initialLoad.providerUid;
    final liveLoads = isProviderFallback ? ref.watch(providerLoadsProvider(user.id)).valueOrNull : null;
    final load = liveLoads?.firstWhere((l) => l.loadId == loadId, orElse: () => initialLoad) ?? initialLoad;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.logLoadViewed(
        loadId: load.loadId,
        originCity: load.pickupLocation,
        destinationCity: load.dropLocation,
        vehicleType: load.truckType,
        budget: int.tryParse(load.budget.replaceAll(RegExp(r'[^0-9]'), '')),
      );
    });

    final isProvider = user.id == load.providerUid;
    final targetTruckOwnerUid = isProvider ? load.assignedTruckOwnerUid : user.id;
    final bookingId = targetTruckOwnerUid != null ? '${load.loadId}_$targetTruckOwnerUid' : null;

    Future<void> deleteLoad() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Load'),
          content: const Text('Delete this load permanently?\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete Load'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        await ref.read(tripOperationsServiceProvider).deleteLoadAtomic(load, user).timeout(const Duration(seconds: 8));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Load deleted successfully'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context); // Pop back to dashboard
        }
      } on TimeoutException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Waiting for internet connection...\nYour action will continue automatically when connected.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } on FirebaseException catch (e) {
        if (context.mounted) {
          if (e.code == 'unavailable') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No internet connection. Please reconnect and try again.'), backgroundColor: AppColors.error),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete load: ${e.message ?? e.toString()}'), backgroundColor: AppColors.error),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppColors.error),
          );
        }
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Load Command Center',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (user.id == load.providerUid && load.status == 'open')
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
              onPressed: deleteLoad,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Status and ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    load.status.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'ID: ${load.loadId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Route
            RichLocationCard(
              label: 'PICKUP',
              fallbackAddress: load.pickupLocation,
              locationDetails: load.pickupLocationDetails,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            RichLocationCard(
              label: 'DELIVERY',
              fallbackAddress: load.dropLocation,
              locationDetails: load.dropLocationDetails,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Info Grid
            Row(
              children: [
                _buildInfoTile('Material', load.materialType, isDark),
                const SizedBox(width: 12),
                _buildInfoTile('Weight', load.weight, isDark),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoTile('Truck Type', load.truckType, isDark),
                const SizedBox(width: 12),
                _buildInfoTile('Budget', LoadFormatters.formatBudget(load.budget), isDark, highlight: true),
              ],
            ),
            const SizedBox(height: 32),

            // Visual Progress Timeline
            TripProgressTimeline(currentStatus: load.tripStatus, isDark: isDark),
            
            const SizedBox(height: 32),

            // Contact Exchange
            if (bookingId != null)
              ref.watch(contactExchangeProvider(bookingId)).when(
                data: (exchange) => Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: ContactExchangeCard(
                    currentUserUid: user.id,
                    exchange: exchange,
                  ),
                ),
                loading: () => Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: ContactExchangeCard(
                    currentUserUid: user.id,
                    exchange: null,
                  ),
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),

            // Assignment
            Text(
              'Operational Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Provider', load.providerName, isDark),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Assigned To',
                    load.assignedTruckOwnerName ?? 'Unassigned',
                    isDark,
                    color: load.assignedTruckOwnerName != null ? AppColors.success : AppColors.warning,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('Created', _formatDate(load.createdAt), isDark),
                  const Divider(height: 24),
                  _buildDetailRow('Last Updated', _formatDate(load.updatedAt), isDark),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Operational Timeline
            Text(
              'Trip Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: ref.watch(tripEventsProvider(load.loadId)).when(
                data: (events) {
                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        'No operational events yet.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: List.generate(events.length, (index) {
                      final event = events[index];
                      // Reverse order? Events are likely descending based on repository.
                      // If descending (newest first), we might want to show them like that, or reverse to show oldest first.
                      // Let's show newest at the top, like an activity feed.
                      return _buildDynamicTimelineNode(
                        event.message,
                        _formatDate(event.createdAt),
                        event.actorName,
                        isDark,
                        isLast: index == events.length - 1,
                      );
                    }),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
            
            // Payment block — only visible after delivery
            if (load.tripStatus == TripStatus.delivered ||
                load.tripStatus == TripStatus.completed) ...[
              const SizedBox(height: 24),
              ref.watch(paymentStreamProvider(load.loadId)).when(
                data: (payment) => PaymentStatusCard(
                  payment: payment,
                  load: load,
                  currentUser: user,
                  isDark: isDark,
                ),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => Text(
                  'Error loading payment state.',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDynamicTimelineNode(String message, String time, String actor, bool isDark, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      actor,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String value, bool isDark, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primaryBlue.withValues(alpha: 0.1) : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: highlight ? AppColors.primaryBlue : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
    );
  }
}
