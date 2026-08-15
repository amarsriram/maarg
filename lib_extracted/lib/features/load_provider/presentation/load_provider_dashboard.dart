import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'tabs/load_provider_home_tab.dart';
import 'tabs/post_load_tab.dart';
import 'tabs/shipments_tab.dart';
import 'tabs/load_provider_profile_tab.dart';

class LoadProviderDashboard extends StatefulWidget {
  const LoadProviderDashboard({super.key});

  @override
  State<LoadProviderDashboard> createState() => _LoadProviderDashboardState();
}

class _LoadProviderDashboardState extends State<LoadProviderDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _tabs = [
    LoadProviderHomeTab(onTabChange: (index) => setState(() => _currentIndex = index)),
    const PostLoadTab(),
    const ShipmentsTab(),
    const LoadProviderProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        height: 100,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : AppColors.lightBorder,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: NavigationBar(
              height: 65,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              indicatorColor: theme.primaryColor.withValues(alpha: 0.1),
              destinations: [
                _buildNavItem(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Home'),
                _buildNavItem(icon: Icons.add_circle_outline_rounded, selectedIcon: Icons.add_circle_rounded, label: 'Post Load'),
                _buildNavItem(icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping_rounded, label: 'Shipments'),
                _buildNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavItem({required IconData icon, required IconData selectedIcon, required String label}) {
    return NavigationDestination(
      icon: Icon(icon, size: 24),
      selectedIcon: Icon(selectedIcon, size: 24),
      label: label,
    );
  }
}
