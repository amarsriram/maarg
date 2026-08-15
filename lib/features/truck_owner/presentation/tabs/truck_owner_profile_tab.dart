import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_model.dart';
import '../../../../core/repositories/metrics_repository.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/utils/load_formatters.dart';
import '../../../../app/app.dart';

// ─── Profile Tab ────────────────────────────────────────────────────────────

class TruckOwnerProfileTab extends ConsumerStatefulWidget {
  const TruckOwnerProfileTab({super.key});

  @override
  ConsumerState<TruckOwnerProfileTab> createState() =>
      _TruckOwnerProfileTabState();
}

class _TruckOwnerProfileTabState extends ConsumerState<TruckOwnerProfileTab> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Text(
            'Sign Out',
            style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPrimary),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.primaryBlue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;
    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: AppColors.error),
        );
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    // ── Existing providers ──
    final availableLoadsAsync =
        ref.watch(availableMarketplaceLoadsCountProvider);
    final activeTripsAsync =
        ref.watch(truckOwnerActiveTripsCountProvider(user.id));
    final completedTripsAsync =
        ref.watch(truckOwnerCompletedTripsCountProvider(user.id));
    final tripsAsync = ref.watch(truckOwnerTripsProvider(user.id));

    // ── Earnings Calculation ──
    int totalEarned = 0;
    int completedCount = 0;
    
    if (tripsAsync.hasValue && tripsAsync.value != null) {
      for (final trip in tripsAsync.value!) {
        if (trip.status == 'completed') {
          completedCount++;
          try {
            totalEarned += LoadFormatters.parseBudgetString(trip.budget);
          } catch (_) {
            // Ignore malformed budgets, do not crash the card
          }
        }
      }
    }
    final avgPayout =
        completedCount > 0 ? (totalEarned / completedCount).round() : 0;

    // ── Member since ──
    final fbUser = FirebaseAuth.instance.currentUser;
    final memberSince = fbUser?.metadata.creationTime != null
        ? DateFormat('MMMM yyyy').format(fbUser!.metadata.creationTime!)
        : 'Recently Joined';

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final labelCol = isDark ? AppColors.darkTextTertiary : AppColors.lightTextSecondary;
    final primaryText = isDark ? Colors.white : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // The floating navbar outer container is exactly 100dp tall (see truck_owner_dashboard.dart)
    // extendBody: true means content scrolls under it — we must clear it fully.
    final mq = MediaQuery.of(context);
    const double navbarHeight = 100.0;
    final bottomPad = mq.padding.bottom + navbarHeight + 32;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: primaryText,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Identity Hero ─────────────────────────────────────────────
            _ProfileIdentityHero(
              user: user,
              memberSince: memberSince,
              isDark: isDark,
              primaryText: primaryText,
              secondaryText: secondaryText,
              labelCol: labelCol,
              surface: surface,
            ),
            const SizedBox(height: 32),

            // ── Earnings ──────────────────────────────────────────────────
            _SectionLabel(title: 'Your Earnings', labelCol: labelCol),
            const SizedBox(height: 12),
            _EarningsCard(
              isLoading: tripsAsync.isLoading,
              hasError: tripsAsync.hasError,
              totalEarned: totalEarned,
              avgPayout: avgPayout,
              isDark: isDark,
              surface: surface,
              cardBorder: cardBorder,
              labelCol: labelCol,
            ),
            const SizedBox(height: 28),

            // ── Operations ────────────────────────────────────────────────
            _SectionLabel(title: 'Operations', labelCol: labelCol),
            const SizedBox(height: 12),
            _OperationsSurface(
              availableLoads: availableLoadsAsync.valueOrNull,
              activeTrips: activeTripsAsync.valueOrNull,
              completedTrips: completedTripsAsync.valueOrNull,
              isDark: isDark,
              surface: surface,
              cardBorder: cardBorder,
              labelCol: labelCol,
              primaryText: primaryText,
            ),
            const SizedBox(height: 28),

            // ── Settings ──────────────────────────────────────────────────
            _SectionLabel(title: 'Settings', labelCol: labelCol),
            const SizedBox(height: 12),
            _SettingsList(
              isDark: isDark,
              surface: surface,
              cardBorder: cardBorder,
              labelCol: labelCol,
              primaryText: primaryText,
              onThemeChange: (val) {
                ref.read(themeModeStateProvider.notifier).state =
                    val ? ThemeMode.dark : ThemeMode.light;
              },
              isDarkTheme: ref.watch(themeModeStateProvider) == ThemeMode.dark,
            ),
            const SizedBox(height: 28),

            // ── Sign Out ──────────────────────────────────────────────────
            _SignOutRow(
              isLoggingOut: _isLoggingOut,
              onTap: _handleLogout,
            ),
            const SizedBox(height: 36),

            // ── Maarg Footer ──────────────────────────────────────────────
            const _MaargFooter(),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final Color labelCol;
  const _SectionLabel({required this.title, required this.labelCol});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: labelCol,
      ),
    );
  }
}

class _ProfileIdentityHero extends StatelessWidget {
  final AppUser user;
  final String memberSince;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final Color labelCol;
  final Color surface;

  const _ProfileIdentityHero({
    required this.user,
    required this.memberSince,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.labelCol,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    // Safe fallbacks for missing identity data
    final displayName = (user.name?.trim().isNotEmpty == true)
        ? user.name!.trim()
        : 'Maarg Operator';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M';
    final hasEmail = user.email.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: surface,
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.4),
              width: 2.0,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasEmail) ...[
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: labelCol, // Muted blue-grey
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user.role.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Member since $memberSince',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: labelCol, // Muted supporting info
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final int totalEarned;
  final int avgPayout;
  final bool isDark;
  final Color surface;
  final Color cardBorder;
  final Color labelCol;

  const _EarningsCard({
    required this.isLoading,
    required this.hasError,
    required this.totalEarned,
    required this.avgPayout,
    required this.isDark,
    required this.surface,
    required this.cardBorder,
    required this.labelCol,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 0.7),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primaryBlue),
        ),
      );
    }

    if (hasError) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 0.7),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: labelCol),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Unable to load earnings',
                style: TextStyle(color: labelCol, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    // Exact Indian formatting (e.g. ₹1,45,000)
    final formatCurrency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final exactAmount = formatCurrency.format(totalEarned);
    // Handle 0 gracefully
    final exactAvg = avgPayout > 0 ? formatCurrency.format(avgPayout) : '—';

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 0.7),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Total Earned
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL EARNED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: labelCol,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exactAmount,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryBlue,
                        letterSpacing: -0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'across completed trips',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: labelCol,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Vertical divider
            VerticalDivider(
              width: 1,
              color: cardBorder,
              indent: 16,
              endIndent: 16,
            ),
            // Right: Avg per Trip
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVG. PER TRIP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: labelCol,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exactAvg,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryLight,
                        letterSpacing: -0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'per completed trip',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: labelCol,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationsSurface extends StatelessWidget {
  final int? availableLoads;
  final int? activeTrips;
  final int? completedTrips;
  final bool isDark;
  final Color surface;
  final Color cardBorder;
  final Color labelCol;
  final Color primaryText;

  const _OperationsSurface({
    required this.availableLoads,
    required this.activeTrips,
    required this.completedTrips,
    required this.isDark,
    required this.surface,
    required this.cardBorder,
    required this.labelCol,
    required this.primaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 0.7),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _CompactStat(
                value: availableLoads?.toString() ?? '—',
                label: 'Available\nLoads',
                primaryText: primaryText,
                labelCol: labelCol,
              ),
            ),
            VerticalDivider(width: 1, color: cardBorder),
            Expanded(
              child: _CompactStat(
                value: activeTrips?.toString() ?? '—',
                label: 'Active\nTrips',
                primaryText: primaryText,
                labelCol: labelCol,
              ),
            ),
            VerticalDivider(width: 1, color: cardBorder),
            Expanded(
              child: _CompactStat(
                value: completedTrips?.toString() ?? '—',
                label: 'Completed\nTrips',
                primaryText: primaryText,
                labelCol: labelCol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String value;
  final String label;
  final Color primaryText;
  final Color labelCol;

  const _CompactStat({
    required this.value,
    required this.label,
    required this.primaryText,
    required this.labelCol,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: labelCol,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  final bool isDark;
  final Color surface;
  final Color cardBorder;
  final Color labelCol;
  final Color primaryText;
  final Function(bool) onThemeChange;
  final bool isDarkTheme;

  const _SettingsList({
    required this.isDark,
    required this.surface,
    required this.cardBorder,
    required this.labelCol,
    required this.primaryText,
    required this.onThemeChange,
    required this.isDarkTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 0.7),
      ),
      child: Column(
        children: [
          _SettingsRow(
            title: 'Dark Theme',
            icon: Icons.dark_mode_outlined,
            labelCol: labelCol,
            primaryText: primaryText,
            trailing: Switch(
              value: isDarkTheme,
              onChanged: onThemeChange,
              activeThumbColor: AppColors.primaryBlue,
            ),
          ),
          Divider(height: 1, indent: 40, color: cardBorder),
          _SettingsRow(
            title: 'Help & Support',
            icon: Icons.help_outline_rounded,
            labelCol: labelCol,
            primaryText: primaryText,
            onTap: () {},
          ),
          Divider(height: 1, indent: 40, color: cardBorder),
          _SettingsRow(
            title: 'Privacy Policy',
            icon: Icons.privacy_tip_outlined,
            labelCol: labelCol,
            primaryText: primaryText,
            onTap: () {},
          ),
          Divider(height: 1, indent: 40, color: cardBorder),
          _SettingsRow(
            title: 'App Version',
            icon: Icons.info_outline_rounded,
            labelCol: labelCol,
            primaryText: primaryText,
            trailing: Text(
              '1.0.0 (42)',
              style: TextStyle(fontSize: 12, color: labelCol),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color labelCol;
  final Color primaryText;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.title,
    required this.icon,
    required this.labelCol,
    required this.primaryText,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // Fixed row height so every row — including the Switch row — is identical.
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: labelCol),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Trailing: Switch, version text, or default chevron — all centred.
              if (trailing != null)
                trailing!
              else
                Icon(Icons.chevron_right, size: 18, color: labelCol),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  final bool isLoggingOut;
  final VoidCallback onTap;

  const _SignOutRow({required this.isLoggingOut, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoggingOut ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.35),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.error.withValues(alpha: isDark ? 0.07 : 0.05),
          ),
          child: isLoggingOut
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.error),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MaargFooter extends StatelessWidget {
  const _MaargFooter();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final col = isDark
        ? AppColors.darkTextTertiary.withValues(alpha: 0.55)
        : AppColors.lightTextSecondary.withValues(alpha: 0.5);
    return Column(
      children: [
        Divider(
          height: 1,
          color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
              .withValues(alpha: 0.4),
        ),
        const SizedBox(height: 20),
        Text(
          'MAARG',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: col,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Built for the road · v1.0.0',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: col,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
