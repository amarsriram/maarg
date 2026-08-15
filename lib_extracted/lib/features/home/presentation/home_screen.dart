import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../../core/widgets/route_visualizer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTruckOwner = user.role == UserRole.truckOwner;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Styled Sliver AppBar
          SliverAppBar(
            expandedHeight: 130.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'Welcome back, ${user.displayName.split(' ').first}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.darkBg, AppColors.darkSurface]
                        : [AppColors.lightSurface, AppColors.lightBg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTruckOwner ? Icons.local_shipping : Icons.business,
                    size: 20,
                    color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                  ),
                ),
                onPressed: () {
                  // Prompt showing profile or information
                },
              ),
              const SizedBox(width: 16),
            ],
          ),

          // Scrollable Home Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Card
                  _buildIntroBanner(context, user),
                  const SizedBox(height: 24),

                  // Section Title
                  Text(
                    'Key Performance Metrics',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Metrics Cards Grid
                  _buildMetricsGrid(context, isTruckOwner),
                  const SizedBox(height: 28),

                  // Recent Activity / Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Return Runs & Transactions',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dynamic list of items
                  _buildActivityList(context, isTruckOwner),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroBanner(BuildContext context, AppUser user) {
    final theme = Theme.of(context);
    final isTruckOwner = user.role == UserRole.truckOwner;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isTruckOwner ? 'Trucker Account' : 'Supplier Account',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                user.companyName ?? '',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isTruckOwner
                ? 'Got empty trucks driving back?'
                : 'Need to ship cargo efficiently?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTruckOwner
                ? 'Post your return routes and let local suppliers bid on your empty capacity. Boost earnings by up to 40%.'
                : 'Search empty trucks on return paths and book cargo space at fraction of standard freight rates.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, bool isTruckOwner) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Metrics for Truck Owners
    final truckerMetrics = [
      _MetricItem(
        label: 'Total Revenue',
        value: '₹1,24,500',
        icon: Icons.currency_rupee,
        color: AppColors.cyanAccent,
      ),
      _MetricItem(
        label: 'Empty Miles Saved',
        value: '3,840 km',
        icon: Icons.trending_down,
        color: AppColors.info,
      ),
      _MetricItem(
        label: 'Broker Fees Tracked',
        value: '₹6,225',
        icon: Icons.percent,
        color: AppColors.accentOrange,
        subtitle: '5% commission',
      ),
      _MetricItem(
        label: 'Active Listed Runs',
        value: '4 Runs',
        icon: Icons.local_shipping_outlined,
        color: AppColors.warning,
      ),
    ];

    // Metrics for Suppliers
    final supplierMetrics = [
      _MetricItem(
        label: 'Freight Savings',
        value: '₹42,800',
        icon: Icons.savings_outlined,
        color: AppColors.cyanAccent,
      ),
      _MetricItem(
        label: 'CO2 Emission Saved',
        value: '1.45 Tons',
        icon: Icons.eco_outlined,
        color: AppColors.success,
      ),
      _MetricItem(
        label: 'Broker Fees Paid',
        value: '₹2,140',
        icon: Icons.percent,
        color: AppColors.accentOrange,
        subtitle: '5% platform fee',
      ),
      _MetricItem(
        label: 'Active Bookings',
        value: '2 Shipments',
        icon: Icons.inventory_2_outlined,
        color: AppColors.warning,
      ),
    ];

    final metrics = isTruckOwner ? truckerMetrics : supplierMetrics;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  Icon(m.icon, color: m.color, size: 20),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                  ),
                  if (m.subtitle != null)
                    Text(
                      m.subtitle ?? '',
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityList(BuildContext context, bool isTruckOwner) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define some simulated recent listings/bookings
    final activities = [
      _ActivityItem(
        source: 'Mumbai, MH',
        destination: 'Ahmedabad, GJ',
        date: '24 May 2026',
        vehicle: 'MH-04-GP-8832',
        price: '₹18,000',
        commission: '₹900',
        status: 'Active / Matching',
        statusColor: AppColors.info,
      ),
      _ActivityItem(
        source: 'Delhi NCR',
        destination: 'Jaipur, RJ',
        date: '22 May 2026',
        vehicle: 'DL-01-AB-1299',
        price: '₹12,500',
        commission: '₹625',
        status: 'Booked',
        statusColor: AppColors.success,
      ),
      _ActivityItem(
        source: 'Bengaluru, KA',
        destination: 'Chennai, TN',
        date: '19 May 2026',
        vehicle: 'KA-51-MM-4491',
        price: '₹22,000',
        commission: '₹1,100',
        status: 'Completed',
        statusColor: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
      ),
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final act = activities[index];

        return Container(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: act.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      act.status,
                      style: TextStyle(
                        color: act.statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    act.date,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RouteVisualizer(
                origin: act.source,
                destination: act.destination,
                isCompact: true,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle / Truck Details',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        act.vehicle,
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Freight Cost: ',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          ),
                          Text(
                            act.price,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Broker Commission (5%): ${act.commission}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    ],
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });
}

class _ActivityItem {
  final String source;
  final String destination;
  final String date;
  final String vehicle;
  final String price;
  final String commission;
  final String status;
  final Color statusColor;

  _ActivityItem({
    required this.source,
    required this.destination,
    required this.date,
    required this.vehicle,
    required this.price,
    required this.commission,
    required this.status,
    required this.statusColor,
  });
}
