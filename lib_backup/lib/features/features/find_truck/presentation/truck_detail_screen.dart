import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/route_visualizer.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/booking_repository.dart';

import '../../post_route/data/route_repository.dart';
import '../domain/truck_model.dart';

class TruckDetailScreen extends ConsumerStatefulWidget {
  final String truckId;
  final TruckRoute? preloadedRoute;

  const TruckDetailScreen({
    super.key,
    required this.truckId,
    this.preloadedRoute,
  });

  @override
  ConsumerState<TruckDetailScreen> createState() => _TruckDetailScreenState();
}

class _TruckDetailScreenState extends ConsumerState<TruckDetailScreen> {
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Load truck route: use preloaded or search list
    final route = widget.preloadedRoute ?? 
        ref.read(routeRepositoryProvider).firstWhere((r) => r.id == widget.truckId);

    final user = ref.watch(authRepositoryProvider).currentUser;

    final double basePrice = route.price;
    final double commission = basePrice * 0.05; // 5%
    final double totalPrice = basePrice + commission;

    Future<void> bookTruck() async {
      if (user == null) return;

      setState(() {
        _isBooking = true;
      });

      final success = await ref.read(bookingRepositoryProvider.notifier).createBooking(route, user);

      if (!context.mounted) return;

      setState(() {
        _isBooking = false;
      });

      if (success) {
        // Show success animation or dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 28),
                const SizedBox(width: 8),
                const Text('Booking Placed!'),
              ],
            ),
            content: Text(
              'Your booking for route ${route.source} to ${route.destination} is placed. '
              'Broker commission has been tracked under your portal.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Pop Dialog
                  context.safeGo('/'); // Navigate back to Dashboard screen
                },
                child: const Text('Go to Bookings'),
              ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Truck Details'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card representing route
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        RouteVisualizer(
                          origin: route.source,
                          destination: route.destination,
                          originSubtitle: 'Available from origin',
                          destinationSubtitle: 'Heading towards final point',
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn(theme, isDark, 'AVAILABLE DATE', DateFormat('dd MMMM yyyy').format(route.date)),
                            _buildInfoColumn(theme, isDark, 'TRUCK SPECIFICATION', route.truckType),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Carrier Info Card
                  Text(
                    'Carrier & Vehicle Details',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.companyName,
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Driver: ${route.ownerName} • ${route.vehicleNumber}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.phone_in_talk, color: AppColors.success),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Pricing Breakdown Panel
                  Text(
                    'Freight Pricing & Commission',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow(
                          label: 'Base Freight Cost',
                          value: '₹${NumberFormat('#,##,###').format(basePrice)}',
                          isBold: false,
                        ),
                        const SizedBox(height: 10),
                        _buildPriceRow(
                          label: 'Broker Commission (5%)',
                          value: '₹${NumberFormat('#,##,###').format(commission)}',
                          isBold: false,
                          labelColor: AppColors.accentOrange,
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _buildPriceRow(
                          label: 'Total Billing amount',
                          value: '₹${NumberFormat('#,##,###').format(totalPrice)}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Bar for Book Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'TOTAL COST',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${NumberFormat('#,##,###').format(totalPrice)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: CustomButton(
                    text: 'Confirm Booking',
                    onPressed: bookTruck,
                    isLoading: _isBooking,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoColumn(ThemeData theme, bool isDark, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPriceRow({
    required String label,
    required String value,
    required bool isBold,
    Color? labelColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 17 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
