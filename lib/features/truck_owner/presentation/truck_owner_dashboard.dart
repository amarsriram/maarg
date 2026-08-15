import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'tabs/truck_owner_home_tab.dart';
import 'tabs/loads_tab.dart';
import 'tabs/trips_tab.dart';
import 'tabs/truck_owner_profile_tab.dart';

class TruckOwnerDashboard extends StatefulWidget {
  final int initialTab;
  const TruckOwnerDashboard({super.key, this.initialTab = 0});

  @override
  State<TruckOwnerDashboard> createState() => _TruckOwnerDashboardState();
}

class _TruckOwnerDashboardState extends State<TruckOwnerDashboard> {
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
  void didUpdateWidget(TruckOwnerDashboard oldWidget) {
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
    TruckOwnerHomeTab(onTabChange: _onTabChange),
    const LoadsTab(),
    const TripsTab(),
    const TruckOwnerProfileTab(),
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
            child: NavigationBar(
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
                _buildNavItem(icon: Icons.search_outlined, selectedIcon: Icons.search_rounded, label: 'Loads'),
                _buildNavItem(icon: Icons.route_outlined, selectedIcon: Icons.route_rounded, label: 'Trips'),
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
