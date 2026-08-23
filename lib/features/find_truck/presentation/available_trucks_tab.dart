import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/repositories/truck_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/safe_parse_utils.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/widgets/custom_shimmer.dart';

class AvailableTrucksTab extends ConsumerStatefulWidget {
  const AvailableTrucksTab({super.key});

  @override
  ConsumerState<AvailableTrucksTab> createState() => _AvailableTrucksTabState();
}

class _AvailableTrucksTabState extends ConsumerState<AvailableTrucksTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Open Body', 'Container', 'Flatbed'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Return Trucks'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search & Filters Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search routes (e.g. Mumbai)',
                      prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filter Chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      
                      return ActionChip(
                        label: Text(filter),
                        labelStyle: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        backgroundColor: isSelected 
                            ? theme.primaryColor 
                            : (isDark ? AppColors.darkSurface : Colors.grey.shade100),
                        side: BorderSide(
                          color: isSelected 
                              ? theme.primaryColor 
                              : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Results Section with Firestore Stream
          Expanded(
            child: StreamBuilder(
              stream: ref.watch(truckRepositoryProvider).watchAvailableTrucks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ShimmerListSkeleton();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error: ${snapshot.error}"),
                  );
                }

                final trucksData = snapshot.data?.docs ?? [];
                
                // Local filtering based on search query and chip filter
                final filteredTrucks = trucksData.where((doc) {
                  final data = doc.data();
                  final truck = (data as Map<String, dynamic>?) ?? {};
                  
                  // Phase 6: Validate truck fields exist safely before rendering
                  if (!SafeParse.isValidTruck(truck)) return false;
                  
                  final query = _searchQuery.toLowerCase();
                  
                  final from = SafeParse.safeString(truck['from'] ?? truck['currentLocation'], '').toLowerCase();
                  final to = SafeParse.safeString(truck['to'] ?? truck['destination'], '').toLowerCase();
                  final type = SafeParse.safeString(truck['type'] ?? truck['truckType'], '').toLowerCase();

                  final matchesQuery = query.isEmpty || from.contains(query) || to.contains(query);
                  final matchesFilter = _selectedFilter == 'All' || type.contains(_selectedFilter);

                  return matchesQuery && matchesFilter;
                }).toList();

                if (filteredTrucks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No trucks found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100), // extra padding for bottom nav
                  itemCount: filteredTrucks.length,
                  itemBuilder: (context, index) {
                    final data = filteredTrucks[index].data();
                    final truck = (data as Map<String, dynamic>?) ?? {};
                    return _buildPremiumTruckCard(truck, theme, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTruckCard(Map<String, dynamic> truck, ThemeData theme, bool isDark) {
    // Graceful fallback for missing fields since we don't have hardcoded data
    final driverName = SafeParse.safeString(truck['driverName'] ?? truck['driver'], 'Unknown Driver');
    final initial = driverName.isNotEmpty ? driverName[0].toUpperCase() : '?';
    final isVerified = SafeParse.safeBool(truck['verified'], false);
    final rating = SafeParse.safeString(truck['rating'], '4.0');
    final trips = SafeParse.safeInt(truck['trips'], 0);
    
    final fromLoc = StringUtils.capitalizeWords(SafeParse.safeString(truck['from'] ?? truck['currentLocation'], 'Unknown'));
    final toLoc = StringUtils.capitalizeWords(SafeParse.safeString(truck['to'] ?? truck['destination'], 'Unknown'));
    final type = SafeParse.safeString(truck['type'] ?? truck['truckType'], 'Truck');
    final capacity = SafeParse.safeString(truck['capacity'], 'N/A');
    
    final priceStr = CurrencyUtils.formatINR(truck['price'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Profile & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    driverName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 14, color: AppColors.primaryLight),
                                  ]
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.star, size: 14, color: Colors.orange.shade400),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "$rating ($trips trips)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: AppColors.cyanAccent),
                      SizedBox(width: 6),
                      Text(
                        "Available",
                        style: TextStyle(
                          color: AppColors.cyanAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Route
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FROM",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fromLoc,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_right_alt, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "TO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        toLoc,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            // Details & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$type • $capacity",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceStr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      "Book",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
