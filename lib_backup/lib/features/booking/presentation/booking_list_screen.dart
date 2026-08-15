import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/route_visualizer.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../data/booking_repository.dart';
import '../domain/booking_model.dart';

class BookingListScreen extends ConsumerWidget {
  const BookingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = ref.watch(authRepositoryProvider).currentUser;
    final allBookings = ref.watch(bookingRepositoryProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTruckOwner = user.role == UserRole.truckOwner;

    // Filter bookings depending on role
    final userBookings = allBookings.where((booking) {
      if (isTruckOwner) {
        // Truck Owner sees bookings made on their trucks (company matches)
        return booking.companyName == user.companyName;
      } else {
        // Supplier sees bookings they created
        return booking.supplierId == user.id;
      }
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
          bottom: TabBar(
            dividerColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            indicatorColor: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
            labelColor: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
            tabs: const [
              Tab(text: 'Active Runs'),
              Tab(text: 'Completed History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Active Runs tab
            _buildBookingTabList(
              context, 
              userBookings.where((b) => b.status != BookingStatus.completed).toList(),
              isDark,
              isTruckOwner,
            ),
            // Completed Runs tab
            _buildBookingTabList(
              context, 
              userBookings.where((b) => b.status == BookingStatus.completed).toList(),
              isDark,
              isTruckOwner,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingTabList(
    BuildContext context, 
    List<Booking> bookings, 
    bool isDark,
    bool isTruckOwner,
  ) {
    final theme = Theme.of(context);

    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 64,
                color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No Bookings in this Category',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isTruckOwner 
                    ? 'Bookings placed on your return routes will show up here.'
                    : 'Search return trucks and book cargo capacity to see runs here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final total = booking.price + booking.brokerCommission;

        Color statusColor;
        switch (booking.status) {
          case BookingStatus.pending:
            statusColor = AppColors.warning;
            break;
          case BookingStatus.confirmed:
            statusColor = AppColors.success;
            break;
          case BookingStatus.completed:
            statusColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
            break;
          case BookingStatus.cancelled:
            statusColor = AppColors.error;
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Booking ID & Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${booking.id.toUpperCase()}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      booking.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Route visualizer
              RouteVisualizer(
                origin: booking.source,
                destination: booking.destination,
                isCompact: true,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Booking specifications
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTruckOwner ? 'CLIENT SUPPLIER' : 'TRUCKING COMPANY',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTruckOwner ? booking.supplierCompanyName : booking.companyName,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DATE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy').format(booking.date),
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL COST',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${NumberFormat('#,##,###').format(total)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Broker commission visual tracker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : AppColors.lightBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.percent, 
                          size: 14, 
                          color: AppColors.accentOrange,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Commission Earned by Broker (5%)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      '₹${NumberFormat('#,##,###').format(booking.brokerCommission)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
