import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_controller.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeStateProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTruckOwner = user.role == UserRole.truckOwner;

    Future<void> toggleRole() async {
      final newRole = isTruckOwner ? UserRole.provider : UserRole.truckOwner;
      
      // Update role via controller
      final success = await ref.read(authControllerProvider.notifier).selectRole(newRole);
      
      if (success) {
        // Reset navigation tab to home to avoid index issues
        // ref.read(dashboardTabProvider.notifier).state = 0;
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched view to ${newRole.displayName}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }

    Future<void> handleLogout() async {
      await ref.read(authControllerProvider.notifier).logout();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Card Header
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: (isDark ? AppColors.primaryLight : AppColors.primaryBlue).withValues(alpha: 0.1),
                    child: Text(
                      user.displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Chip(
                    avatar: Icon(
                      isTruckOwner ? Icons.local_shipping : Icons.business,
                      size: 14,
                      color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                    ),
                    label: Text(
                      user.role.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                      ),
                    ),
                    backgroundColor: (isDark ? AppColors.primaryLight : AppColors.primaryBlue).withValues(alpha: 0.08),
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // User Info Details Section
            _buildSectionTitle(theme, 'Company & Contact Details'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.domain,
                    label: 'Company Name',
                    value: user.companyName ?? 'Not Configured',
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildProfileTile(
                    icon: Icons.phone_android,
                    label: 'Contact Number',
                    value: user.phoneNumber ?? 'Not Configured',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preference settings Section
            _buildSectionTitle(theme, 'App Settings & Preferences'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  // Theme Selector
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Dark Theme Mode'),
                      trailing: Switch(
                        value: themeMode == ThemeMode.dark,
                        onChanged: (isDarkTheme) {
                          ref.read(themeModeStateProvider.notifier).state =
                              isDarkTheme ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  
                  // Role Switcher Switch (Testing helper)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.swap_horizontal_circle_outlined),
                      title: const Text('Switch Active Role'),
                      subtitle: Text(
                        'Currently viewing: ${isTruckOwner ? "Truck Owner" : "Supplier"} dashboard',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.swap_calls, color: AppColors.accentOrange),
                        onPressed: toggleRole,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sign Out
            OutlinedButton(
              onPressed: handleLogout,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out Account', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
