import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../dashboard/presentation/load_detail_screen.dart';

class TripsTab extends ConsumerWidget {
  const TripsTab({super.key});

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

    final tripsStream = ref.watch(truckOwnerTripsProvider(user.id));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: Text(
            'My Trips',
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
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: tripsStream.when(
          data: (trips) {
            final activeTrips = trips.where((t) => t.status != 'completed').toList();
            final completedTrips = trips.where((t) => t.status == 'completed').toList();

            return TabBarView(
              children: [
                _TripsList(trips: activeTrips, isDark: isDark, emptyMessage: 'No active trips'),
                _TripsList(trips: completedTrips, isDark: isDark, emptyMessage: 'No completed trips'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
          error: (err, stack) => Center(
            child: Text(
              'Error loading trips.\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  const _TripsList({required this.trips, required this.isDark, required this.emptyMessage});
  
  final List<LoadModel> trips;
  final bool isDark;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
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
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _TripCard(trip: trip, isDark: isDark);
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.isDark});

  final LoadModel trip;
  final bool isDark;

  Color get _statusColor {
    switch (trip.status.toLowerCase()) {
      case 'open':
        return AppColors.info;
      case 'booked':
      case 'dispatched':
      case 'in_transit':
      case 'arrived':
      case 'unloading':
        return AppColors.primaryBlue;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.darkTextTertiary;
    }
  }

  String get _statusLabel {
    return trip.status.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoadDetailScreen(loadId: trip.loadId, initialLoad: trip),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip.budget,
                    style: TextStyle(
                      color: trip.status == 'completed' ? AppColors.success : AppColors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (trip.status == 'completed')
                    const Text(
                      'Payout Received',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Route
          Text(
            '${trip.pickupLocation} → ${trip.dropLocation}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          
          // Material / Weight / Date
          Text(
            '${trip.weight} • ${trip.materialType} • ${trip.pickupDate}',
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
                    Icon(Icons.business_center_outlined, size: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'Provider: ${trip.providerName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'ID: ${trip.loadId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
