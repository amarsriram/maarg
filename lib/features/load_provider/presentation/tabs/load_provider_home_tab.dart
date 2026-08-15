import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/repositories/analytics_repository.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/repositories/booking_repository.dart';
import '../../../../core/models/trip_status.dart';
import '../../../../core/models/load_model.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../notifications/presentation/notification_feed_screen.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';
import 'shipments_tab.dart';

class LoadProviderHomeTab extends ConsumerWidget {
  const LoadProviderHomeTab({super.key, this.onTabChange});
  final Function(int)? onTabChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final loadsAsync = ref.watch(providerLoadsProvider(user.id));
    final pendingBookingsAsync = ref.watch(providerPendingBookingsProvider(user.id));

    final loads = loadsAsync.valueOrNull ?? [];
    final pendingBookings = pendingBookingsAsync.valueOrNull ?? [];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App Bar ─────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 120.0,
          floating: false,
          pinned: true,
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
            title: Text(
              'Welcome back, ${user.displayName.split(' ').first}',
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

        // ── Body ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── KPI Overview Cards ─────────────────────────────────
                _SectionLabel(text: 'Overview', isDark: isDark),
                const SizedBox(height: 12),
                _buildKpiRow(isDark, ref, user.id),
                const SizedBox(height: 24),

                // ── Quick Action CTA ───────────────────────────────────
                _buildPostLoadCta(context, isDark),
                const SizedBox(height: 28),
                
                // ── Operational Summary ────────────────────────────────
                _SectionLabel(text: 'Action Center', isDark: isDark),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),

        // ── Operational Action Items ────────────────────────────────────
        // Each stream handles its own loading/error state independently.
        // If one stream fails, the other cards still render.

        // ── Pending Bookings Card (independent) ─────────────────────────
        if (pendingBookingsAsync.isLoading)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else if (pendingBookingsAsync.hasError)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else if (pendingBookings.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: _ActionCard(
                title: 'Pending Booking Requests (${pendingBookings.length})',
                subtitle: 'Truck owners have requested to transport your loads.',
                buttonText: 'Review Requests',
                icon: Icons.assignment_late_outlined,
                color: AppColors.info,
                isDark: isDark,
                onTap: () {
                  ref.read(shipmentsSubTabProvider.notifier).state = 0;
                  onTabChange?.call(2);
                },
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox.shrink()),

        // ── Loads-based Cards (Active Trips + Waiting for Completion) ────
        if (loadsAsync.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
            ),
          )
        else if (loadsAsync.hasError)
          SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Error loading data.',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          )
        else
          _buildLoadsActionCards(loads, isDark, ref),
           
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildLoadsActionCards(List<LoadModel> loads, bool isDark, WidgetRef ref) {
    final waitingForCompletion = loads.where((l) => l.tripStatus == TripStatus.delivered).toList();
    final activeTrips = loads.where((l) => [
      TripStatus.assigned, 
      TripStatus.en_route_pickup, 
      TripStatus.loaded, 
      TripStatus.in_transit
    ].contains(l.tripStatus)).toList();

    if (waitingForCompletion.isEmpty && activeTrips.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                const SizedBox(height: 16),
                Text(
                  'No pending actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
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
        delegate: SliverChildListDelegate([
          // Priority 1: Waiting for Completion
          for (final load in waitingForCompletion)
            _ActionCard(
              title: 'Waiting for Completion',
              subtitle: '${load.pickupLocation} → ${load.dropLocation}',
              buttonText: 'Complete Trip',
              icon: Icons.check_circle_outline,
              color: AppColors.warning,
              isDark: isDark,
              onTap: () {
                ref.read(shipmentsSubTabProvider.notifier).state = 1;
                onTabChange?.call(2);
              },
            ),
            
          // Priority 2: Active Trips
          for (final load in activeTrips)
            _ActionCard(
              title: 'Active Trip',
              subtitle: '${load.pickupLocation} → ${load.dropLocation}',
              buttonText: 'View Trip (${load.tripStatus.displayName})',
              icon: Icons.local_shipping_outlined,
              color: AppColors.primaryBlue,
              isDark: isDark,
              onTap: () {
                ref.read(shipmentsSubTabProvider.notifier).state = 1;
                onTabChange?.call(2);
              },
            ),
        ]),
      ),
    );
  }

  // ── KPI Row ───────────────────────────────────────────────────────────
  Widget _buildKpiRow(bool isDark, WidgetRef ref, String uid) {
    final analyticsAsync = ref.watch(providerAnalyticsProvider(uid));

    return analyticsAsync.when(
      data: (analytics) {
        return _buildStaticKpiRow(
          isDark, 
          analytics.activeShipments,
          analytics.completedShipments,
          analytics.delayedShipments,
          analytics.completedShipments, 
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _buildStaticKpiRow(isDark, 0, 0, 0, 0),
    );
  }

  Widget _buildStaticKpiRow(bool isDark, int active, int inTransit, int delayed, int delivered) {
    return Row(
      children: [
        Expanded(child: _KpiTile(label: 'Active', value: '$active', icon: Icons.local_shipping_outlined, accent: AppColors.primaryBlue, isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _KpiTile(label: 'In Transit', value: '${active > 0 ? active - delayed : 0}', icon: Icons.route_outlined, accent: AppColors.info, isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _KpiTile(label: 'Delayed', value: '$delayed', icon: Icons.schedule, accent: AppColors.warning, isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _KpiTile(label: 'Delivered', value: '$delivered', icon: Icons.check_circle_outline, accent: AppColors.success, isDark: isDark)),
      ],
    );
  }

  // ── Post Load CTA ─────────────────────────────────────────────────────
  Widget _buildPostLoadCta(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onTabChange?.call(1);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post New Load',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Find available trucks instantly',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 20),
              ],
            ),
          ),
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

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.7,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  buttonText, 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
