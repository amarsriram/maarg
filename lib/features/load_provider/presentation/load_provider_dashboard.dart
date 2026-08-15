import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/repositories/load_repository.dart';
import '../../../core/repositories/booking_repository.dart';
import '../../../core/models/trip_status.dart';
import '../../auth/data/auth_repository.dart';
import 'tabs/load_provider_home_tab.dart';
import 'tabs/post_load_tab.dart';
import 'tabs/shipments_tab.dart';
import 'tabs/load_provider_profile_tab.dart';

class LoadProviderDashboard extends StatefulWidget {
  final int initialTab;
  const LoadProviderDashboard({super.key, this.initialTab = 0});

  @override
  State<LoadProviderDashboard> createState() => _LoadProviderDashboardState();
}

class _LoadProviderDashboardState extends State<LoadProviderDashboard> {
  late int _currentIndex;
  late final List<bool> _visitedTabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _visitedTabs = List<bool>.filled(4, false);
    _visitedTabs[_currentIndex] = true;
  }

  @override
  void didUpdateWidget(LoadProviderDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _currentIndex = widget.initialTab;
        _visitedTabs[_currentIndex] = true;
      });
    }
  }

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
      _visitedTabs[index] = true;
    });
  }

  late final List<Widget> _tabs = [
    LoadProviderHomeTab(onTabChange: _onTabChange),
    PostLoadTab(onTabChange: _onTabChange),
    ShipmentsTab(onTabChange: _onTabChange),
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
        children: List.generate(_tabs.length, (index) {
          return _visitedTabs[index] ? _tabs[index] : const SizedBox.shrink();
        }),
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
            child: Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authStateProvider);
                final user = authState.value;
                int badgeCount = 0;

                if (user != null) {
                  final loadsAsync = ref.watch(providerLoadsProvider(user.id));
                  final pendingBookingsAsync = ref.watch(providerPendingBookingsProvider(user.id));

                  final loads = loadsAsync.valueOrNull ?? [];
                  final pendingBookings = pendingBookingsAsync.valueOrNull ?? [];

                  // Each stream contributes independently — a failure in one
                  // does not prevent the other from contributing to the badge.
                  badgeCount += loads.where((l) => l.tripStatus == TripStatus.delivered).length;
                  badgeCount += pendingBookings.length;
                }

                return NavigationBar(
                  height: 65,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                      _visitedTabs[index] = true;
                    });
                  },
                  indicatorColor: theme.primaryColor.withValues(alpha: 0.1),
                  destinations: [
                    _buildNavItem(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Home'),
                    _buildNavItem(icon: Icons.add_circle_outline_rounded, selectedIcon: Icons.add_circle_rounded, label: 'Post Load'),
                    _buildNavItem(
                      icon: Icons.local_shipping_outlined, 
                      selectedIcon: Icons.local_shipping_rounded, 
                      label: 'Shipments',
                      badgeCount: badgeCount,
                    ),
                    _buildNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavItem({
    required IconData icon, 
    required IconData selectedIcon, 
    required String label,
    int badgeCount = 0,
  }) {
    return NavigationDestination(
      icon: badgeCount > 0 
          ? Badge(
              label: Text(badgeCount.toString()),
              backgroundColor: AppColors.error,
              child: Icon(icon, size: 24),
            )
          : Icon(icon, size: 24),
      selectedIcon: badgeCount > 0
          ? Badge(
              label: Text(badgeCount.toString()),
              backgroundColor: AppColors.error,
              child: Icon(selectedIcon, size: 24),
            )
          : Icon(selectedIcon, size: 24),
      label: label,
    );
  }
}
