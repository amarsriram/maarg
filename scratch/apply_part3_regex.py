import re

with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update imports
imports_to_add = """import '../../../../core/models/trip_status.dart';
import '../../../../core/models/load_request_state.dart';
import '../../../../core/utils/load_formatters.dart';
"""
if "import '../../../../core/models/trip_status.dart';" not in content:
    content = content.replace("import '../../../../core/models/load_model.dart';", 
                              "import '../../../../core/models/load_model.dart';\n" + imports_to_add)

# 2. Update state resolution logic
old_state_res = re.search(r'// 1\. Resolve State.*?\n    return CustomScrollView\(', content, re.DOTALL)
if old_state_res:
    new_state_res = """    // 1. Resolve State — distinguish loading / error / empty / data
    DriverHomeState state = DriverHomeState.loading;
    List<LoadModel>? loads;
    LoadModel? activeTrip;
    bool hasLoadError = false;
    bool hasTripError = false;

    if (availableLoadsStream.isLoading || activeTripsStream.isLoading) {
      state = DriverHomeState.loading;
    } else if (activeTripsStream.hasError) {
      hasTripError = true;
      state = DriverHomeState.activeTrip; // Distinguishes active trip error
    } else if (availableLoadsStream.hasError) {
      // Real error — must NOT appear as empty marketplace
      hasLoadError = true;
      state = DriverHomeState.emptyMarketplace; // re-used slot; hasLoadError flag distinguishes
    } else {
      final trips = activeTripsStream.value ?? [];
      activeTrip = trips.where((t) => t.status != 'completed').firstOrNull;
      loads = availableLoadsStream.value ?? [];

      if (activeTrip != null) {
        state = DriverHomeState.activeTrip;
      } else if (loads.isNotEmpty) {
        state = DriverHomeState.idle;
      } else {
        state = DriverHomeState.emptyMarketplace;
      }
    }

    return CustomScrollView("""
    content = content[:old_state_res.start()] + new_state_res + content[old_state_res.end():]


# 3. Update _buildStateWorkspace call
content = content.replace(
    ": _buildStateWorkspace(state, isDark, loads),",
    ": _buildStateWorkspace(state, isDark, loads, activeTrip, hasTripError),"
)

# 4. Update _buildStateWorkspace func
old_build_ws = re.search(r'Widget _buildStateWorkspace\(DriverHomeState state.*?\n  }', content, re.DOTALL)
if old_build_ws:
    new_build_ws = """Widget _buildStateWorkspace(DriverHomeState state, bool isDark, List<LoadModel>? loads, LoadModel? activeTrip, bool hasTripError) {
    switch (state) {
      case DriverHomeState.loading:
        return _buildLoadingHome(isDark);
      case DriverHomeState.idle:
        return _buildIdleHome(isDark, loads ?? []);
      case DriverHomeState.emptyMarketplace:
        return _buildEmptyMarketplaceHome(isDark);
      case DriverHomeState.activeTrip:
        if (hasTripError) return _buildActiveTripErrorHome(isDark);
        if (activeTrip == null) return _buildLoadingHome(isDark);
        return _buildActiveTripHome(isDark, activeTrip);
      case DriverHomeState.pendingRequests:
        return _buildPendingRequestsHome(isDark);
    }
  }"""
    content = content[:old_build_ws.start()] + new_build_ws + content[old_build_ws.end():]

# 5. Replace _buildActiveTripHome and append classes
old_active_home = re.search(r'Widget _buildActiveTripHome\(bool isDark\) \{.*?\n  \}', content, re.DOTALL)
if old_active_home:
    active_trip_home_and_classes = """Widget _buildActiveTripHome(bool isDark, LoadModel trip) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: SliverToBoxAdapter(
        child: _ActiveTripWorkspace(trip: trip, isDark: isDark, onTabChange: widget.onTabChange),
      ),
    );
  }

  Widget _buildActiveTripErrorHome(bool isDark) {
    final bodyColor = isDark ? Colors.white54 : Colors.black54;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 36, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 14),
              Text(
                'UNABLE TO LOAD ACTIVE TRIP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text('Check your connection and try again.', style: TextStyle(color: bodyColor, fontSize: 13)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
              ),
            ],
          ),
        ),
      ),
    );
  }"""
    content = content[:old_active_home.start()] + active_trip_home_and_classes + content[old_active_home.end():]

with open('scratch/active_trip_composer.dart', 'r', encoding='utf-8') as f:
    composer_content = f.read()

classes_part = composer_content[composer_content.find('class _ActiveTripWorkspace extends ConsumerStatefulWidget {'):]

if 'class _ActiveTripWorkspace extends ConsumerStatefulWidget' not in content:
    content += "\n\n" + classes_part

with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Applied changes with regex!")
