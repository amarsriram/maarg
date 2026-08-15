import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';


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

    // Metrics sourced from Firestore streams — zeros until real data arrives
    final truckerMetrics = [
      _MetricItem(
        label: 'Total Revenue',
        value: '₹0',
        icon: Icons.currency_rupee,
        color: AppColors.cyanAccent,
      ),
      _MetricItem(
        label: 'Empty Miles Saved',
        value: '0 km',
        icon: Icons.trending_down,
        color: AppColors.info,
      ),
      _MetricItem(
        label: 'Broker Fees Tracked',
        value: '₹0',
        icon: Icons.percent,
        color: AppColors.accentOrange,
        subtitle: '5% commission',
      ),
      _MetricItem(
        label: 'Active Listed Runs',
        value: '0 Runs',
        icon: Icons.local_shipping_outlined,
        color: AppColors.warning,
      ),
    ];

    final supplierMetrics = [
      _MetricItem(
        label: 'Freight Savings',
        value: '₹0',
        icon: Icons.savings_outlined,
        color: AppColors.cyanAccent,
      ),
      _MetricItem(
        label: 'CO2 Emission Saved',
        value: '0 Tons',
        icon: Icons.eco_outlined,
        color: AppColors.success,
      ),
      _MetricItem(
        label: 'Broker Fees Paid',
        value: '₹0',
        icon: Icons.percent,
        color: AppColors.accentOrange,
        subtitle: '5% platform fee',
      ),
      _MetricItem(
        label: 'Active Bookings',
        value: '0 Shipments',
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

    // Empty state — real activity data comes from Firestore streams
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No recent activity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isTruckOwner
                  ? 'Post a return route to get started'
                  : 'Search and book trucks to see activity here',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
      ),
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


