import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/repositories/booking_repository.dart';
import '../../../../core/repositories/analytics_repository.dart';
import '../../../../core/repositories/notification_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../notifications/presentation/notification_feed_screen.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';

class TruckOwnerHomeTab extends ConsumerStatefulWidget {
  const TruckOwnerHomeTab({super.key, this.onTabChange});
  final Function(int)? onTabChange;

  @override
  ConsumerState<TruckOwnerHomeTab> createState() => _TruckOwnerHomeTabState();
}

class _TruckOwnerHomeTabState extends ConsumerState<TruckOwnerHomeTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    final availableLoadsStream = ref.watch(availableLoadsProvider);
    
    // Listen to active trips
    final activeTripsStream = user != null ? ref.watch(truckOwnerTripsProvider(user.id)) : const AsyncValue<List<LoadModel>>.data([]);

    return activeTripsStream.when(
      data: (trips) {
        final activeTrip = trips.where((t) => t.status != 'completed').firstOrNull;
        final bool hasActiveTrip = activeTrip != null;
        
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App Bar ─────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
                title: Text(
                  'Welcome back, ${user?.driverDisplayName.split(' ').first ?? 'Driver'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    letterSpacing: -0.3,
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
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: NotificationBadge(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationFeedScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Body ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Earnings Snapshot ───────────────────────────────
                    _buildEarningsRow(isDark, ref, user?.id),
                    const SizedBox(height: 20),

                    // ── Context-Aware Hero ──────────────────────────────
                    hasActiveTrip
                        ? _buildActiveTripHero(context, isDark, activeTrip)
                        : availableLoadsStream.when(
                            data: (loads) => _buildOpportunityHero(context, isDark, loads.length),
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => _buildOpportunityHero(context, isDark, 0),
                          ),
                    const SizedBox(height: 20),

                    // ── Dynamic CTA ─────────────────────────────────────
                    _buildDynamicCta(isDark, hasActiveTrip),
                    const SizedBox(height: 28),

                    // ── Feed Header ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionLabel(
                          text: hasActiveTrip ? 'Trip Milestones' : 'Available Loads',
                          isDark: isDark,
                        ),
                        if (!hasActiveTrip)
                          availableLoadsStream.when(
                            data: (loads) => Text(
                              '${loads.length} nearby',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // ── Feed Cards ──────────────────────────────────────────────
            hasActiveTrip
                ? _buildMilestoneSliver(isDark, activeTrip)
                : availableLoadsStream.when(
                    data: (loads) => _buildLoadsSliver(isDark, loads),
                    loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                    error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
                  ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading trip state: $e')),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  EARNINGS SNAPSHOT
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildEarningsRow(bool isDark, WidgetRef ref, String? uid) {
    if (uid == null) {
      return _buildStaticEarningsRow(isDark, 0, 0, 4.8);
    }

    final analyticsAsync = ref.watch(truckOwnerAnalyticsProvider(uid));

    return analyticsAsync.when(
      data: (analytics) => _buildStaticEarningsRow(isDark, analytics.weeklyEarnings, analytics.completedTrips, analytics.rating),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildStaticEarningsRow(isDark, 0, 0, 4.8),
    );
  }

  Widget _buildStaticEarningsRow(bool isDark, int earnings, int trips, double rating) {
    // Format earnings nicely
    final formattedEarnings = earnings >= 1000 ? '${(earnings / 1000).toStringAsFixed(1)}k' : earnings.toString();
    
    return Row(
      children: [
        Expanded(
          child: _EarningsTile(
            label: 'Total Earned',
            value: '₹$formattedEarnings',
            trend: 'lifetime',
            trendPositive: true,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _EarningsTile(
            label: 'Trips Done',
            value: '$trips',
            trend: 'total',
            trendPositive: true,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _EarningsTile(
            label: 'Rating',
            value: rating.toStringAsFixed(1),
            trend: '★',
            trendPositive: true,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  STATE 1 — ACTIVE TRIP HERO
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildActiveTripHero(BuildContext context, bool isDark, LoadModel activeTrip) {
    // For now we assume progress is 0 since this is a new booking.
    const progressFraction = 0.1;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: Status + ETA ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.cyanAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'IN TRANSIT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'ETA: TBD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Route ──────────────────────────────────────────────
            Text(
              '${activeTrip.pickupLocation} → ${activeTrip.dropLocation}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Heading to destination',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),

            // ── Progress Bar ───────────────────────────────────────
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trip Started',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progressFraction * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Payout + Details Row ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TripMeta(label: 'Payout', value: activeTrip.budget, highlight: true),
                  _tripDot(),
                  _TripMeta(label: 'Status', value: activeTrip.status.toUpperCase()),
                  _tripDot(),
                  _TripMeta(label: 'Load ID', value: activeTrip.loadId.substring(0, 6)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  STATE 2 — OPPORTUNITY HERO
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildOpportunityHero(BuildContext context, bool isDark, int loadCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.radar, color: AppColors.cyanAccent, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Scanning loads near you',
                style: TextStyle(
                  color: AppColors.cyanAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$loadCount Loads Available',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Live opportunities fetched from market',
            style: TextStyle(
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DYNAMIC CTA
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDynamicCta(bool isDark, bool hasActiveTrip) {
    final isTrip = hasActiveTrip;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isTrip ? null : AppColors.primaryGradient,
        color: isTrip ? (isDark ? AppColors.darkSurface : Colors.white) : null,
        borderRadius: BorderRadius.circular(16),
        border: isTrip
            ? Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 0.7)
            : null,
        boxShadow: isTrip
            ? null
            : [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onTabChange?.call(1);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isTrip
                        ? (isDark ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.primaryBlue.withValues(alpha: 0.08))
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTrip ? Icons.edit_note_rounded : Icons.search_rounded,
                    color: isTrip ? AppColors.primaryBlue : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTrip ? 'Update Trip Status' : 'Browse Available Loads',
                        style: TextStyle(
                          color: isTrip ? (isDark ? Colors.white : AppColors.lightTextPrimary) : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTrip ? 'Log delay, arrival, or report issue' : 'Find your next profitable trip',
                        style: TextStyle(
                          color: isTrip ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary) : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: isTrip ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary) : Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MILESTONE SLIVER (active trip state)
  // ════════════════════════════════════════════════════════════════════════

  SliverPadding _buildMilestoneSliver(bool isDark, LoadModel trip) {
    final milestones = [
      {'label': 'Booking Accepted', 'time': 'Done', 'done': true},
      {'label': 'Arrive at ${trip.pickupLocation}', 'time': 'Pending', 'done': ['in_transit', 'arrived', 'unloading', 'completed'].contains(trip.status)},
      {'label': 'Deliver to ${trip.dropLocation}', 'time': 'Pending', 'done': ['completed'].contains(trip.status)},
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= milestones.length) return null;
            final m = milestones[index];
            final done = m['done'] as bool;
            final isLast = index == milestones.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 120 : 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Timeline Gutter ──────────────────────────────
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: done ? AppColors.success : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              shape: BoxShape.circle,
                              border: done
                                  ? null
                                  : Border.all(
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                      width: 1.5,
                                    ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 1.5,
                                color: done ? AppColors.success.withValues(alpha: 0.3) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ── Content ──────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['label'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                                color: done
                                    ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                                    : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              m['time'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (done)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                      ),
                  ],
                ),
              ),
            );
          },
          childCount: milestones.length,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  AVAILABLE LOADS SLIVER (no-trip state)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildLoadsSliver(bool isDark, List<LoadModel> loads) {
    if (loads.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 12),
                Text(
                  'No loads available',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= loads.length) return null;
            final load = loads[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == loads.length - 1 ? 120 : 12,
              ),
              child: _LoadCard(
                route: '${load.pickupLocation} → ${load.dropLocation}',
                distance: 'Live Load',
                payout: load.budget,
                truckType: load.truckType,
                urgency: 'Scheduled',
                pickup: load.pickupDate,
                weight: load.weight,
                commodity: load.materialType,
                isDark: isDark,
              ),
            );
          },
          childCount: loads.length,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Compact earnings / stats tile.
class _EarningsTile extends StatelessWidget {
  const _EarningsTile({
    required this.label,
    required this.value,
    required this.trend,
    required this.trendPositive,
    required this.isDark,
  });

  final String label;
  final String value;
  final String trend;
  final bool trendPositive;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.7,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: trendPositive ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metadata chip inside the active trip hero card.
class _TripMeta extends StatelessWidget {
  const _TripMeta({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 14 : 11,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: Colors.white.withValues(alpha: highlight ? 1.0 : 0.8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Premium available-load card.
class _LoadCard extends StatelessWidget {
  const _LoadCard({
    required this.route,
    required this.distance,
    required this.payout,
    required this.truckType,
    required this.urgency,
    required this.pickup,
    required this.weight,
    required this.commodity,
    required this.isDark,
  });

  final String route;
  final String distance;
  final String payout;
  final String truckType;
  final String weight;
  final String commodity;
  final String urgency;
  final String pickup;
  final bool isDark;

  Color get _urgencyColor {
    switch (urgency) {
      case 'Urgent':
        return AppColors.warning;
      case 'Scheduled':
        return AppColors.primaryBlue;
      default:
        return AppColors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top: Urgency + Payout ───────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _UrgencyBadge(label: urgency, accent: _urgencyColor, isDark: isDark),
                    Text(
                      payout,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cyanAccent,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Route ───────────────────────────────────────────
                Text(
                  route,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$distance · $weight · $commodity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Bottom metadata bar ─────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg.withValues(alpha: 0.5) : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      const SizedBox(width: 6),
                      Text(
                        pickup,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          truckType,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped urgency badge.
class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({
    required this.label,
    required this.accent,
    required this.isDark,
  });

  final String label;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
