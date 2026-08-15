import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/route_visualizer.dart';
import '../../../core/utils/context_extensions.dart';
import '../../post_route/data/route_repository.dart';
import '../domain/truck_model.dart';

class FindTruckScreen extends ConsumerStatefulWidget {
  const FindTruckScreen({super.key});

  @override
  ConsumerState<FindTruckScreen> createState() => _FindTruckScreenState();
}

class _FindTruckScreenState extends ConsumerState<FindTruckScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  String _searchQueryOrigin = '';
  String _searchQueryDestination = '';
  
  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    setState(() {
      _searchQueryOrigin = _originController.text.trim().toLowerCase();
      _searchQueryDestination = _destinationController.text.trim().toLowerCase();
    });
  }

  void _resetSearch() {
    setState(() {
      _originController.clear();
      _destinationController.clear();
      _searchQueryOrigin = '';
      _searchQueryDestination = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Watch all posted routes
    final allRoutes = ref.watch(routeRepositoryProvider);
    
    // Filter routes based on search queries
    final filteredRoutes = allRoutes.where((route) {
      if (route.status != TruckStatus.available) return false;
      
      final matchesOrigin = _searchQueryOrigin.isEmpty || 
          route.source.toLowerCase().contains(_searchQueryOrigin);
      
      final matchesDest = _searchQueryDestination.isEmpty || 
          route.destination.toLowerCase().contains(_searchQueryDestination);
      
      return matchesOrigin && matchesDest;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Return Trucks'),
      ),
      body: Column(
        children: [
          // Filter Form panel
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _originController,
                        label: 'From',
                        hintText: 'e.g. Mumbai',
                        prefixIcon: const Icon(Icons.circle_outlined, size: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _destinationController,
                        label: 'To',
                        hintText: 'e.g. Ahmedabad',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_searchQueryOrigin.isNotEmpty || _searchQueryDestination.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: OutlinedButton(
                          onPressed: _resetSearch,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                    Expanded(
                      child: CustomButton(
                        text: 'Search Empty Trucks',
                        height: 48,
                        onPressed: _triggerSearch,
                        icon: const Icon(Icons.search, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Active Listings / Results
          Expanded(
            child: filteredRoutes.isEmpty
                ? _buildEmptyState(theme, isDark)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRoutes.length,
                    itemBuilder: (context, index) {
                      final route = filteredRoutes[index];
                      return _buildTruckCard(context, route, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 72,
              color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Available Trucks Found',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try resetting your search query or looking for common shipping lanes (Mumbai, Delhi, Bengaluru).',
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

  Widget _buildTruckCard(BuildContext context, TruckRoute route, bool isDark) {
    final theme = Theme.of(context);
    final commission = route.price * 0.05; // 5% broker commission

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Navigate to Detail view with GoRouter extra payload safely
              context.safePush('/truck/${route.id}', extra: route);
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upper Row: Company Name and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.companyName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.star, color: AppColors.accentAmber, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '4.8 (Verified Owner)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${NumberFormat('#,##,###').format(route.price)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '+ ₹${commission.toInt()} broker fee (5%)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Route Visualization
                  RouteVisualizer(
                    origin: route.source,
                    destination: route.destination,
                    isCompact: true,
                  ),
                  const SizedBox(height: 16),

                  // Lower Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailBadge(
                        context: context,
                        icon: Icons.calendar_today_outlined,
                        label: DateFormat('dd MMM').format(route.date),
                      ),
                      _buildDetailBadge(
                        context: context,
                        icon: Icons.local_shipping_outlined,
                        label: route.truckType,
                      ),
                      _buildDetailBadge(
                        context: context,
                        icon: Icons.scale_outlined,
                        label: '${route.capacity} Tons',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBadge({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
