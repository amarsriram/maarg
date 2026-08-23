import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/profile/profile_avatar.dart';
import '../../../../core/widgets/profile/profile_info_card.dart';
import '../../../../core/widgets/profile/profile_stats_card.dart';
import '../../../../core/widgets/profile/settings_tile.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/domain/user_model.dart';
import '../../../../core/repositories/metrics_repository.dart';
import '../../../../app/app.dart';

class LoadProviderProfileTab extends ConsumerStatefulWidget {
  const LoadProviderProfileTab({super.key});

  @override
  ConsumerState<LoadProviderProfileTab> createState() => _LoadProviderProfileTabState();
}

class _LoadProviderProfileTabState extends ConsumerState<LoadProviderProfileTab> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Text(
            'Sign Out',
            style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPrimary),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.primaryBlue)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalLoads = ref.watch(providerTotalLoadsCountProvider(user.id)).valueOrNull?.toString() ?? '-';
    final activeShipments = ref.watch(providerActiveShipmentsCountProvider(user.id)).valueOrNull?.toString() ?? '-';
    final completedDeliveries = ref.watch(providerCompletedDeliveriesCountProvider(user.id)).valueOrNull?.toString() ?? '-';
    final fbUser = FirebaseAuth.instance.currentUser;
    final creationTime = fbUser?.metadata.creationTime;
    final memberSince = creationTime != null 
        ? DateFormat('MMMM yyyy').format(creationTime) 
        : 'Recently Joined';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Avatar
              ProfileAvatar(name: user.displayName, isDark: isDark),
              const SizedBox(height: 24),
              
              // Profile Info Card
              ProfileInfoCard(
                name: user.providerDisplayName,
                email: user.email ?? user.phoneNumber ?? 'No contact info',
                roleBadge: user.role.displayName,
                memberSince: memberSince,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              
              // Stats Card
              ProfileStatsCard(
                title: 'Operations Overview',
                stat1Label: 'Total Loads',
                stat1Value: totalLoads,
                stat2Label: 'Active',
                stat2Value: activeShipments,
                stat3Label: 'Delivered',
                stat3Value: completedDeliveries,
                isDark: isDark,
              ),
              const SizedBox(height: 32),
              
              // Settings Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.7,
                  ),
                ),
                child: Column(
                  children: [
                    SettingsTile(
                      title: 'Dark Theme',
                      icon: Icons.dark_mode_outlined,
                      isDark: isDark,
                      trailing: Switch(
                        value: ref.watch(themeModeStateProvider) == ThemeMode.dark,
                        onChanged: (val) {
                          ref.read(themeModeStateProvider.notifier).state =
                              val ? ThemeMode.dark : ThemeMode.light;
                        },
                        activeThumbColor: AppColors.primaryBlue,
                      ),
                    ),
                    Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    SettingsTile(
                      title: 'Help & Support',
                      icon: Icons.help_outline_rounded,
                      isDark: isDark,
                      onTap: () {},
                    ),
                    Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    SettingsTile(
                      title: 'Privacy Policy',
                      icon: Icons.privacy_tip_outlined,
                      isDark: isDark,
                      onTap: () {},
                    ),
                    Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    SettingsTile(
                      title: 'App Version',
                      subtitle: '1.0.0 (Build 42)',
                      icon: Icons.info_outline_rounded,
                      isDark: isDark,
                      trailing: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoggingOut ? null : _handleLogout,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoggingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
