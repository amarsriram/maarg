import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/repositories/analytics_repository.dart';
import '../../../../core/repositories/notification_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../notifications/presentation/notification_feed_screen.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';
import '../../../post_load/presentation/post_load_screen.dart';

// ---------------------------------------------------------------------------
// Dummy operational data — will be replaced with Firestore streams later.
// ---------------------------------------------------------------------------

const List<Map<String, String>> _shipments = [
  {
    'id': '#MGR-2048',
    'route': 'Hyderabad → Bangalore',
    'status': 'In Transit',
    'eta': '6h 20m',
    'truck': 'MH-12-AB-1234',
    'weight': '18 Tons',
    'commodity': 'Electronics',
  },
  {
    'id': '#MGR-2051',
    'route': 'Mumbai → Pune',
    'status': 'Delayed',
    'eta': '2h Delay',
    'truck': 'KA-05-CD-7890',
    'weight': '22 Tons',
    'commodity': 'Steel Coils',
  },
  {
    'id': '#MGR-2038',
    'route': 'Chennai → Kochi',
    'status': 'Delivered',
    'eta': 'Completed',
    'truck': 'TN-09-EF-4567',
    'weight': '14 Tons',
    'commodity': 'FMCG Goods',
  },
  {
    'id': '#MGR-2044',
    'route': 'Delhi NCR → Jaipur',
    'status': 'In Transit',
    'eta': '3h 45m',
    'truck': 'RJ-14-GH-2345',
    'weight': '20 Tons',
    'commodity': 'Cement Bags',
  },
];

class LoadProviderHomeTab extends ConsumerWidget {
  const LoadProviderHomeTab({super.key, this.onTabChange});
  final Function(int)? onTabChange;

  // ── Status helpers ──────────────────────────────────────────────────────
  static Color _statusAccent(String status) {
    switch (status) {
      case 'In Transit':
        return AppColors.primaryBlue;
      case 'Delayed':
        return AppColors.warning;
      case 'Delivered':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'In Transit':
        return Icons.local_shipping_outlined;
      case 'Delayed':
        return Icons.schedule;
      case 'Delivered':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

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
              'Welcome back, ${user?.displayName.split(' ').first ?? 'Provider'}',
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
                _buildKpiRow(isDark, ref, user?.id),
                const SizedBox(height: 24),

                // ── Quick Action CTA ───────────────────────────────────
                _buildPostLoadCta(context, isDark),
                const SizedBox(height: 28),

                // ── Shipment Feed ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionLabel(text: 'Active Shipments', isDark: isDark),
                    Text(
                      '${_shipments.length} total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),

        // ── Shipment Cards (as sliver list for performance) ───────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _shipments.length) return null;
                final s = _shipments[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _shipments.length - 1 ? 120 : 12,
                  ),
                  child: _ShipmentCard(
                    id: s['id']!,
                    route: s['route']!,
                    status: s['status']!,
                    eta: s['eta']!,
                    truck: s['truck']!,
                    weight: s['weight']!,
                    commodity: s['commodity']!,
                    accent: _statusAccent(s['status']!),
                    icon: _statusIcon(s['status']!),
                    isDark: isDark,
                  ),
                );
              },
              childCount: _shipments.length,
            ),
          ),
        ),
      ],
    );
  }

  // ── KPI Row ───────────────────────────────────────────────────────────
  Widget _buildKpiRow(bool isDark, WidgetRef ref, String? uid) {
    if (uid == null) {
      return _buildStaticKpiRow(isDark, 0, 0, 0, 0);
    }

    final analyticsAsync = ref.watch(providerAnalyticsProvider(uid));

    return analyticsAsync.when(
      data: (analytics) {
        return _buildStaticKpiRow(
          isDark, 
          analytics.activeShipments,
          analytics.completedShipments, // Or another metric like in transit vs completed
          analytics.delayedShipments,
          analytics.completedShipments, 
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildStaticKpiRow(isDark, 0, 0, 0, 0),
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostLoadScreen()),
            );
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

/// Section label used above overview and shipment sections.
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

/// Compact KPI tile used in the 4‑across overview row.
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

/// Premium shipment card with status badge, route, and operational metadata.
class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({
    required this.id,
    required this.route,
    required this.status,
    required this.eta,
    required this.truck,
    required this.weight,
    required this.commodity,
    required this.accent,
    required this.icon,
    required this.isDark,
  });

  final String id;
  final String route;
  final String status;
  final String eta;
  final String truck;
  final String weight;
  final String commodity;
  final Color accent;
  final IconData icon;
  final bool isDark;

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
                // ── Top Row: ID + Status Badge ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      id,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    _StatusBadge(label: status, accent: accent, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Route ───────────────────────────────────────────
                Row(
                  children: [
                    Icon(icon, size: 18, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        route,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Bottom metadata row ─────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBg.withValues(alpha: 0.5)
                        : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _MetaChip(label: 'ETA', value: eta, isDark: isDark),
                      _metaDot(isDark),
                      _MetaChip(label: 'Truck', value: truck, isDark: isDark),
                      _metaDot(isDark),
                      _MetaChip(label: 'Load', value: weight, isDark: isDark),
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

  Widget _metaDot(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Compact metadata chip used inside the shipment card's bottom bar.
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

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
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped status badge with tinted background.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
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
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
