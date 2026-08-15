import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_model.dart';
import '../constants/app_colors.dart';
import '../location/location_service.dart';

class LocationSelectorBottomSheet extends ConsumerStatefulWidget {
  final String title;

  const LocationSelectorBottomSheet({super.key, required this.title});

  static Future<LocationModel?> show(BuildContext context, {required String title}) {
    return showModalBottomSheet<LocationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSelectorBottomSheet(title: title),
    );
  }

  @override
  ConsumerState<LocationSelectorBottomSheet> createState() => _LocationSelectorBottomSheetState();
}

class _LocationSelectorBottomSheetState extends ConsumerState<LocationSelectorBottomSheet> {
  final List<LocationModel> _recentLocations = [];
  
  List<LocationModel> _filteredLocations = [];
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Initially show recents or empty
    _filteredLocations = [];
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final trimmedQuery = query.trim();

    if (trimmedQuery.length < 3) {
      setState(() {
        _filteredLocations = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final locationService = ref.read(locationServiceProvider);
        final results = await locationService.searchLocations(trimmedQuery);
        
        if (mounted) {
          setState(() {
            _filteredLocations = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _filteredLocations = [];
            _isSearching = false;
          });
        }
      }
    });
  }

  Future<void> _selectLocation(LocationModel location) async {
    final locationService = ref.read(locationServiceProvider);
    
    try {
      final detailedLocation = await locationService.getPlaceDetails(location.id);
      
      final finalLocation = detailedLocation ?? location;

      // Add to recents, keep max 5
      _recentLocations.removeWhere((l) => l.id == finalLocation.id);
      _recentLocations.insert(0, finalLocation);
      if (_recentLocations.length > 5) {
        _recentLocations.removeLast();
      }
      
      if (mounted) {
        Navigator.of(context).pop(finalLocation);
      }
    } catch (e) {
      debugPrint('Failed to get detailed location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not fetch place details. Please try another location.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Do not pop the bottom sheet. Let the user try again.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Material(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search city, state (min 3 chars)...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_isSearching)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: [
                      if (_searchController.text.length < 3 && _recentLocations.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Recent',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                        ..._recentLocations.map((loc) => ListTile(
                              leading: const Icon(Icons.history, color: Colors.grey),
                              title: Text(loc.displayName),
                              subtitle: Text(loc.state),
                              onTap: () => _selectLocation(loc),
                            )),
                        const Divider(),
                      ],
                      if (_searchController.text.length >= 3 && _filteredLocations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('No locations found')),
                        )
                      else if (_searchController.text.length < 3 && _recentLocations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('Start typing to search locations...')),
                        )
                      else
                        ..._filteredLocations.map((loc) => ListTile(
                              leading: const Icon(Icons.location_on_outlined, color: AppColors.primaryBlue),
                              title: Text(loc.displayName),
                              subtitle: Text(loc.state.isNotEmpty ? loc.state : 'Unknown'),
                              onTap: () => _selectLocation(loc),
                            )),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
