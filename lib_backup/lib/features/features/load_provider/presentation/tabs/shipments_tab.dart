import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/models/trip_status.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/repositories/booking_repository.dart';
import '../../../../core/services/trip_operations_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../dashboard/presentation/load_detail_screen.dart';

class ShipmentsTab extends ConsumerWidget {
  const ShipmentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authStateProvider);
    if (authState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final user = authState.value;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final loadsStream = ref.watch(providerLoadsProvider(user.id));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: Text(
            'My Shipments',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          bottom: TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            indicatorColor: AppColors.primaryBlue,
            tabs: const [
              Tab(text: 'Open'),
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: loadsStream.when(
          data: (loads) {
            final openLoads = loads.where((l) => l.status == 'open').toList();
            final activeLoads = loads.where((l) => !['open', 'completed'].contains(l.status)).toList();
            final completedLoads = loads.where((l) => l.status == 'completed').toList();

            return TabBarView(
              children: [
                _LoadsList(loads: openLoads, isDark: isDark, emptyMessage: 'No open shipments'),
                _LoadsList(loads: activeLoads, isDark: isDark, emptyMessage: 'No active shipments'),
                _LoadsList(loads: completedLoads, isDark: isDark, emptyMessage: 'No completed shipments'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
          error: (err, stack) => Center(
            child: Text(
              'Error loading shipments.\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadsList extends StatelessWidget {
  const _LoadsList({required this.loads, required this.isDark, required this.emptyMessage});
  final List<LoadModel> loads;
  final bool isDark;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (loads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: loads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final load = loads[index];
        return _ShipmentCard(load: load, isDark: isDark);
      },
    );
  }
}

class _ShipmentCard extends ConsumerWidget {
  const _ShipmentCard({required this.load, required this.isDark});

  final LoadModel load;
  final bool isDark;

  Color get _statusColor {
    switch (load.tripStatus) {
      case TripStatus.open:
        return AppColors.info;
      case TripStatus.requested:
      case TripStatus.assigned:
      case TripStatus.en_route_pickup:
      case TripStatus.loaded:
      case TripStatus.in_transit:
      case TripStatus.delivered:
        return AppColors.primaryBlue;
      case TripStatus.completed:
        return AppColors.success;
      case TripStatus.cancelled:
      case TripStatus.disputed:
        return AppColors.error;
    }
  }

  String get _statusLabel {
    return load.tripStatus.displayName.toUpperCase();
  }

  Future<void> _updateStatus(WidgetRef ref, BuildContext context, TripStatus newStatus) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    try {
      await ref.read(tripOperationsServiceProvider).advanceLoadStatus(load, newStatus, user);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${newStatus.displayName}'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteLoad(WidgetRef ref, BuildContext context) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    
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
      await ref.read(tripOperationsServiceProvider).deleteLoadAtomic(load, user);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Load deleted successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      debugPrint('DELETE LOAD FAILED: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildActionButtons(WidgetRef ref, BuildContext context) {
    if (load.tripStatus == TripStatus.open) return const SizedBox.shrink(); // handled by bookings stream
    
    TripStatus? nextStatus;
    String? buttonText;

    switch (load.tripStatus) {
      case TripStatus.assigned:
        nextStatus = TripStatus.en_route_pickup;
        buttonText = 'Dispatch Load';
        break;
      case TripStatus.en_route_pickup:
        nextStatus = TripStatus.loaded;
        buttonText = 'Mark Loaded';
        break;
      case TripStatus.loaded:
        nextStatus = TripStatus.in_transit;
        buttonText = 'Mark In Transit';
        break;
      case TripStatus.in_transit:
        nextStatus = TripStatus.delivered;
        buttonText = 'Mark Arrived/Delivered';
        break;
      case TripStatus.delivered:
        nextStatus = TripStatus.completed;
        buttonText = 'Complete Trip';
        break;
      default:
        break;
    }

    if (nextStatus != null && buttonText != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _updateStatus(ref, context, nextStatus!),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonText),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsStream = load.status == 'open' ? ref.watch(loadBookingsProvider(load.loadId)) : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoadDetailScreen(loadId: load.loadId, initialLoad: load),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status + Budget
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    load.budget,
                    style: const TextStyle(
                      color: AppColors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (load.status == 'open') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppColors.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _deleteLoad(ref, context),
                    ),
                  ]
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Route
          Text(
            '${load.pickupLocation} → ${load.dropLocation}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          
          // Material / Weight / Date
          Text(
            '${load.weight} • ${load.materialType} • ${load.pickupDate}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg.withValues(alpha: 0.5) : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                    const SizedBox(width: 6),
                    Text(
                      load.truckType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'ID: ${load.loadId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          if (load.assignedTruckOwnerName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, size: 14, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 8),
                Text(
                  'Assigned to: ${load.assignedTruckOwnerName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],

          _buildActionButtons(ref, context),

          // Pending Booking Requests (only if open)
          if (bookingsStream != null)
            bookingsStream.when(
              data: (bookings) {
                final pendingBookings = bookings.where((b) => b.status == 'pending').toList();
                if (pendingBookings.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    const SizedBox(height: 8),
                    Text(
                      'Booking Requests (${pendingBookings.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...pendingBookings.map((b) => _BookingRequestCard(booking: b, load: load, isDark: isDark)),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
      ),
    );
  }
}

class _BookingRequestCard extends ConsumerStatefulWidget {
  const _BookingRequestCard({required this.booking, required this.load, required this.isDark});

  final BookingModel booking;
  final LoadModel load;
  final bool isDark;

  @override
  ConsumerState<_BookingRequestCard> createState() => _BookingRequestCardState();
}

class _BookingRequestCardState extends ConsumerState<_BookingRequestCard> {
  bool _isProcessing = false;

  Future<void> _handleAccept() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _isProcessing = true);
    debugPrint('SHIPMENT ACCEPT: bookingId=${widget.booking.bookingId}, loadId=${widget.booking.loadId}');
    try {
      await ref.read(tripOperationsServiceProvider).acceptBooking(widget.booking, user);
      debugPrint('SHIPMENT ACCEPT: SUCCESS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Load assigned successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      debugPrint('SHIPMENT ACCEPT FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _isProcessing = true);
    try {
      await ref.read(tripOperationsServiceProvider).rejectBooking(widget.booking, user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rejected'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.booking.truckOwnerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'Requested to carry this load',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
