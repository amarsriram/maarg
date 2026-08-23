import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/safe_parse_utils.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/widgets/custom_shimmer.dart';

class BookingsTab extends StatelessWidget {
  const BookingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: isDark ? AppColors.darkBg : Colors.white,
          bottom: TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            indicatorColor: theme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(text: 'Active Runs'),
              Tab(text: 'Completed History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookingsList(isActiveTab: true),
            _BookingsList(isActiveTab: false),
          ],
        ),
      ),
    );
  }
}

class _BookingsList extends ConsumerWidget {
  final bool isActiveTab;
  
  const _BookingsList({required this.isActiveTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookingRepositoryProvider);
    return StreamBuilder(
      stream: repo.watchAllBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerListSkeleton();
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allDocs = snapshot.data?.docs ?? [];
        
        final filteredDocs = allDocs.where((doc) {
          final raw = doc.data();
          final data = (raw as Map<String, dynamic>?) ?? {};
          
          // Phase 6: Validate booking fields exist safely before rendering
          if (!SafeParse.isValidBooking(data)) return false;
          
          final statusRaw = SafeParse.safeString(data['status'], '').toLowerCase();
          
          final isCompletedStatus = statusRaw == 'completed' || statusRaw == 'delivered';
          return isActiveTab ? !isCompletedStatus : isCompletedStatus;
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState(
            context, 
            isActiveTab ? "No Active Runs" : "No History", 
            isActiveTab ? "You don't have any loads in transit." : "Your completed deliveries will appear here.",
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16).copyWith(bottom: 100),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final bookingId = filteredDocs[index].id;
            final raw = filteredDocs[index].data();
            final data = (raw as Map<String, dynamic>?) ?? {};
            return _PremiumBookingCard(
              bookingId: bookingId,
              booking: data, 
              isActive: isActiveTab,
            );
          },
        );
      },
    );
  }
}

Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 80,
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
          ),
        ),
      ],
    ),
  );
}

class _PremiumBookingCard extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> booking;
  final bool isActive;

  const _PremiumBookingCard({
    required this.bookingId,
    required this.booking, 
    required this.isActive,
  });

  int _calculateProgress(String status) {
    final s = status.toLowerCase();
    if (s.contains('deliver') || s.contains('complet')) return 3;
    if (s.contains('transit') || s.contains('way')) return 2;
    if (s.contains('pick')) return 1;
    return 0; // pending
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rawStatus = SafeParse.safeString(booking['status'], 'Pending');
    final safeStatus = rawStatus;
    final progress = _calculateProgress(safeStatus);
    
    final displayStatus = StringUtils.capitalizeWords(safeStatus);
    final displayId = bookingId.length > 6 ? bookingId.substring(0, 6).toUpperCase() : bookingId.toUpperCase();
    
    final priceStr = CurrencyUtils.formatINR(booking['price'] ?? 0);
    
    final fromRaw = SafeParse.safeString(booking['from'] ?? booking['pickupLocation'], 'Unknown');
    final toRaw = SafeParse.safeString(booking['to'] ?? booking['dropLocation'], 'Unknown');
    final fromLoc = StringUtils.capitalizeWords(fromRaw);
    final toLoc = StringUtils.capitalizeWords(toRaw);
    
    final driverRaw = SafeParse.safeString(booking['driver'] ?? booking['driverName'], 'Unassigned');
    final driverName = driverRaw;
    final truckRaw = SafeParse.safeString(booking['truck'] ?? booking['truckType'], 'Unknown Truck');
    final truckDetails = truckRaw;

    Color statusColor;
    if (progress == 3) {
      statusColor = AppColors.success;
    } else if (progress == 2) {
      statusColor = AppColors.primaryBlue;
    } else {
      statusColor = AppColors.primaryLight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Column(
        children: [
          // Header with ID and Status Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOOKING ID',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#$displayId',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        displayStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Timeline Tracking UI
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Column(
                  children: [
                    _TimelineDot(isCompleted: progress >= 0, isDark: isDark, theme: theme),
                    _TimelineLine(isCompleted: progress >= 1, isDark: isDark, theme: theme),
                    _TimelineDot(isCompleted: progress >= 1, isDark: isDark, theme: theme),
                    _TimelineLine(isCompleted: progress >= 3, isDark: isDark, theme: theme),
                    _TimelineDot(isCompleted: progress >= 3, isDark: isDark, theme: theme),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TimelineText(
                        title: "Pickup",
                        subtitle: fromLoc,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      _TimelineText(
                        title: progress >= 3 ? "Delivered By" : "In Transit",
                        subtitle: "Driver: $driverName",
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      _TimelineText(
                        title: "Destination",
                        subtitle: toLoc,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Footer with Truck details and Price
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          truckDetails,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  priceStr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final bool isCompleted;
  final bool isDark;
  final ThemeData theme;

  const _TimelineDot({required this.isCompleted, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isCompleted ? theme.primaryColor : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted ? theme.primaryColor : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          width: 2,
        ),
      ),
    );
  }
}

class _TimelineLine extends StatelessWidget {
  final bool isCompleted;
  final bool isDark;
  final ThemeData theme;

  const _TimelineLine({required this.isCompleted, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 30,
      color: isCompleted ? theme.primaryColor : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
    );
  }
}

class _TimelineText extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const _TimelineText({required this.title, required this.subtitle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
