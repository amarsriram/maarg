import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/models/trip_status.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/repositories/contact_exchange_repository.dart';
import '../../../../core/services/trip_operations_service.dart';
import '../../../../core/utils/load_formatters.dart';
import '../../../../core/widgets/contact_exchange_card.dart';
import '../../../../core/repositories/payment_repository.dart';
import '../../../../core/widgets/payment_status_card.dart';
import '../../../auth/data/auth_repository.dart';

class TripsTab extends ConsumerWidget {
  const TripsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authStateProvider);
    if (authState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final user = authState.value;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final tripsStream = ref.watch(truckOwnerTripsProvider(user.id));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          title: Text(
            'My Trips',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          bottom: TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            indicatorColor: AppColors.primaryBlue,
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: tripsStream.when(
          data: (trips) {
            // Operational trip: assigned → en_route_pickup → loaded → in_transit
            // Only ONE at a time; pick the most recently updated.
            final operationalTrips = trips
                .where((t) => t.tripStatus.isOperational)
                .toList();
            final activeTrip = operationalTrips.isNotEmpty ? operationalTrips.first : null;

            // Delivered but not yet provider-confirmed — can coexist with a new active trip.
            final pendingConfirmation = trips
                .where((t) => t.tripStatus == TripStatus.delivered)
                .toList();

            // Completed: provider has confirmed — history.
            final completedTrips = trips
                .where((t) => t.status == 'completed')
                .toList();

            return TabBarView(
              children: [
                _ActiveTripWorkspace(
                  activeTrip: activeTrip,
                  pendingConfirmation: pendingConfirmation,
                  isDark: isDark,
                ),
                _TripsList(trips: completedTrips, isDark: isDark, emptyMessage: 'No completed trips'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
          error: (err, stack) => Center(
            child: Text(
              'Error loading trips.\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  const _TripsList({required this.trips, required this.isDark, required this.emptyMessage});
  
  final List<LoadModel> trips;
  final bool isDark;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'NO COMPLETED TRIPS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your completed trips will appear here.",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
      );
    }

    int totalPayout = trips.fold(0, (sum, trip) => sum + LoadFormatters.parseBudgetString(trip.budget));

    return Column(
      children: [
        // ── History Summary Header ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRIP HISTORY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trips.length} completed trips',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL EARNED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LoadFormatters.formatCompactInr(totalPayout),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // ── History List ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _HistoryCard(trip: trips[index], isDark: isDark);
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.trip, required this.isDark});
  
  final LoadModel trip;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final pickupParsed = LoadFormatters.parseLocation(trip.pickupLocation);
    final dropParsed = LoadFormatters.parseLocation(trip.dropLocation);
    final payoutVal = LoadFormatters.parseBudgetString(trip.budget);
    final primaryText = isDark ? Colors.white : Colors.black;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryText = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Route & Payout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickupParsed.city,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Icon(Icons.arrow_downward_rounded, size: 14, color: isDark ? Colors.white30 : Colors.black38),
                    ),
                    Text(
                      dropParsed.city,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    payoutVal > 0 ? LoadFormatters.formatCompactInr(payoutVal) : '₹0',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: payoutVal > 0 ? AppColors.primaryLight : tertiaryText,
                    ),
                  ),
                  if (payoutVal > 0)
                    Text(
                      'Payout Received',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Row 2: Cargo & Vehicle
          Text(
            LoadFormatters.formatCompatibilityLine(trip.materialType, trip.weight, trip.truckType),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          
          // Row 3: Bottom Metadata
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg.withValues(alpha: 0.5) : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.business_center_outlined, size: 12, color: tertiaryText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.providerName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  LoadFormatters.formatPickupDate(trip.pickupDate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tertiaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTripWorkspace extends ConsumerStatefulWidget {
  const _ActiveTripWorkspace({
    required this.activeTrip,
    required this.pendingConfirmation,
    required this.isDark,
  });

  final LoadModel? activeTrip;
  final List<LoadModel> pendingConfirmation;
  final bool isDark;

  @override
  ConsumerState<_ActiveTripWorkspace> createState() => _ActiveTripWorkspaceState();
}

class _ActiveTripWorkspaceState extends ConsumerState<_ActiveTripWorkspace> {
  bool _isUpdating = false;

  /// Returns the next valid truck-owner-driven transition, or null if none.
  (TripStatus, String, String)? get _currentActionState {
    if (widget.activeTrip == null) return null;
    switch (widget.activeTrip!.tripStatus) {
      case TripStatus.assigned:
        return (TripStatus.en_route_pickup, 'Trip assigned. Ready to begin pickup.', 'Confirm Departure');
      case TripStatus.en_route_pickup:
        return (TripStatus.loaded, 'Head to the pickup location.', 'Mark Loaded');
      case TripStatus.loaded:
        return (TripStatus.in_transit, 'Cargo loaded. Ready to begin transit.', 'Start Transit');
      case TripStatus.in_transit:
        return (TripStatus.delivered, 'Shipment is currently in transit.', 'Mark Delivered');
      default:
        return null;
    }
  }

  Future<void> _advanceStatus(TripStatus nextStatus) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || widget.activeTrip == null) return;

    setState(() => _isUpdating = true);
    try {
      await ref.read(tripOperationsServiceProvider)
          .advanceLoadStatus(widget.activeTrip!, nextStatus, user)
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${nextStatus.displayName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waiting for internet connection...\nYour action will continue automatically when connected.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        if (e.code == 'unavailable') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection. Please reconnect and try again.'), backgroundColor: AppColors.error),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: ${e.message ?? e.toString()}'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _advanceStatusForLoad(LoadModel trip, TripStatus nextStatus) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isUpdating = true);
    try {
      await ref.read(tripOperationsServiceProvider)
          .advanceLoadStatus(trip, nextStatus, user)
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${nextStatus.displayName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waiting for internet connection...\nYour action will continue automatically when connected.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.activeTrip;
    if (trip == null) {
      // Case A: truly empty — no active trip and no pending confirmations
      if (widget.pendingConfirmation.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 64, color: widget.isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(
                'NO ACTIVE TRIP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white60 : Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You're currently free for a new trip.",
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        );
      }
      // Case B: no active trip but pending confirmations exist — show both
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNoActiveTripBanner(),
            const SizedBox(height: 24),
            _buildPendingSection(widget.pendingConfirmation),
          ],
        ),
      );
    }

    final actionState = _currentActionState;
    final isDelivered = trip.tripStatus == TripStatus.delivered;
    final hasPersistentCTA = !isDelivered && actionState != null;

    // Two-layer layout:
    //   Layer A — Expanded scrollable workspace
    //   Layer B — Persistent primary-action region (outside scroll)
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, hasPersistentCTA ? 12 : 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── B. Trip Hero ──
                _buildHero(trip),
                const SizedBox(height: 24),

                // ── C. Shipment Summary ──
                _buildSummary(trip),
                const SizedBox(height: 24),

                // ── Contact Exchange (above status — driver sees contact immediately) ──
                Builder(
                  builder: (context) {
                    final user = ref.watch(authStateProvider).value;
                    final bookingId = user != null ? '${trip.loadId}_${user.id}' : null;
                    if (bookingId == null) return const SizedBox.shrink();

                    return ref.watch(contactExchangeProvider(bookingId)).when(
                      data: (exchange) => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: ContactExchangeCard(
                          currentUserUid: user!.id,
                          exchange: exchange,
                        ),
                      ),
                      loading: () => Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: ContactExchangeCard(
                          currentUserUid: user!.id,
                          exchange: null,
                        ),
                      ),
                      error: (err, stack) => const SizedBox.shrink(),
                    );
                  },
                ),

                // ── D. Trip Lifecycle Progress ──
                _buildProgress(trip),
                const SizedBox(height: 32),

                // ── E / G. Operational State or Delivered State ──
                if (isDelivered)
                  _buildDeliveredState()
                else if (actionState != null)
                  _buildOperationalState(actionState),

                const SizedBox(height: 32),

                // ── F. Provider Metadata ──
                _buildProviderMetadata(trip),

                // ── G. Pending Provider Confirmation (below active workspace) ──
                if (widget.pendingConfirmation.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildPendingSection(widget.pendingConfirmation),
                ],
              ],
            ),
          ),
        ),
        // Layer B: Persistent CTA — always visible, outside scroll
        if (hasPersistentCTA)
          _buildPersistentAction(actionState),
      ],
    );
  }

  Widget _buildHero(LoadModel trip) {
    final pickupParsed = LoadFormatters.parseLocation(trip.pickupLocation);
    final dropParsed = LoadFormatters.parseLocation(trip.dropLocation);
    
    final primaryText = widget.isDark ? Colors.white : Colors.black;
    final secondaryText = widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'ACTIVE TRIP',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildHeroLocation(pickupParsed.city, pickupParsed.state, primaryText, secondaryText),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Icon(Icons.arrow_downward_rounded, size: 20, color: secondaryText.withValues(alpha: 0.5)),
        ),
        _buildHeroLocation(dropParsed.city, dropParsed.state, primaryText, secondaryText),
      ],
    );
  }

  Widget _buildHeroLocation(String city, String state, Color primary, Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          city,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: primary,
            letterSpacing: -0.5,
          ),
        ),
        if (state.isNotEmpty)
          Text(
            state,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: secondary,
            ),
          ),
      ],
    );
  }

  Widget _buildSummary(LoadModel trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryLabel('BUDGET'),
                const SizedBox(height: 4),
                Text(
                  trip.budget.isNotEmpty ? LoadFormatters.formatBudget(trip.budget) : '₹0',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryLabel('CARGO • WEIGHT • VEHICLE'),
                const SizedBox(height: 4),
                Text(
                  '${trip.materialType} • ${trip.weight} • ${trip.truckType}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildProgress(LoadModel trip) {
    final status = trip.tripStatus;
    
    final steps = [
      (TripStatus.assigned, 'Assigned'),
      (TripStatus.en_route_pickup, 'En Route to Pickup'),
      (TripStatus.loaded, 'Loaded'),
      (TripStatus.in_transit, 'In Transit'),
      (TripStatus.delivered, 'Delivered'),
    ];

    int currentIndex = steps.indexWhere((s) => s.$1 == status);
    if (currentIndex == -1) {
      if (status == TripStatus.completed) currentIndex = 4;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryLabel('TRIP PROGRESS'),
        const SizedBox(height: 16),
        ...List.generate(steps.length, (index) {
          final isCompleted = index < currentIndex;
          final isCurrent = index == currentIndex;
          final isLast = index == steps.length - 1;
          
          return _buildProgressStep(
            label: steps[index].$2,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            isLast: isLast,
          );
        }),
      ],
    );
  }

  Widget _buildProgressStep({
    required String label,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final color = isCurrent
        ? AppColors.primaryBlue
        : (isCompleted ? AppColors.success : (widget.isDark ? Colors.white24 : Colors.black26));
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppColors.success : (isCurrent ? AppColors.primaryBlue : Colors.transparent),
                  border: Border.all(
                    color: isCurrent || isCompleted ? color : (widget.isDark ? Colors.white24 : Colors.black26),
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.success : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? (widget.isDark ? Colors.white : Colors.black)
                      : (widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Informational current-state panel (CTA lives in _buildPersistentAction below)
  Widget _buildOperationalState((TripStatus, String, String) actionState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.activeTrip!.tripStatus.displayName.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            actionState.$2,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Layer B: Persistent action region — sits outside SingleChildScrollView
  Widget _buildPersistentAction((TripStatus, String, String) actionState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A), // matches AppColors.darkBg
        border: Border(
          top: BorderSide(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _advanceStatus(actionState.$1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    actionState.$3,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveredState() {
    final trip = widget.activeTrip!;
    final user = ref.read(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Delivery completion banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              const Text(
                'DELIVERY COMPLETED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Live payment actions — same logic as _buildPendingCard
        ref.watch(paymentStreamProvider(trip.loadId)).when(
          data: (payment) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaymentStatusCard(
                payment: payment,
                load: trip,
                currentUser: user,
                isDark: widget.isDark,
              ),
              if (payment != null && payment.status == 'confirmed') ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : () => _advanceStatusForLoad(trip, TripStatus.completed),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('COMPLETE TRIP',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (err, _) => Text(
            'Error loading payment state.',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderMetadata(LoadModel trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryLabel('PROVIDER INFORMATION'),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isDark ? AppColors.darkSurface : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Icon(Icons.business, size: 20, color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.providerName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Trip ID: ${trip.loadId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }


  // ── Empty-state banner (used when no operational trip but pending items exist) ──
  Widget _buildNoActiveTripBanner() {
    return Row(
      children: [
        Icon(Icons.assignment_turned_in_outlined, size: 28,
            color: widget.isDark ? Colors.white24 : Colors.black26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NO ACTIVE TRIP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white60 : Colors.black54,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "You're free for a new trip.",
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Pending Provider Confirmation section ──
  Widget _buildPendingSection(List<LoadModel> pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PENDING PROVIDER CONFIRMATION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        ...pending.map((trip) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPendingCard(trip),
            )),
      ],
    );
  }

  // ── Compact delivered-but-unconfirmed card ──
  Widget _buildPendingCard(LoadModel trip) {
    final pickupParsed = LoadFormatters.parseLocation(trip.pickupLocation);
    final dropParsed = LoadFormatters.parseLocation(trip.dropLocation);
    final primaryText = widget.isDark ? Colors.white : Colors.black;
    final secondaryText =
        widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final paymentState = ref.watch(paymentStreamProvider(trip.loadId));
    final payment = paymentState.value;
    final isConfirmed = payment != null && payment.status == 'confirmed';
    
    final badgeColor = isConfirmed ? AppColors.success : AppColors.warning;
    final badgeText = isConfirmed ? 'Payment Confirmed' : 'Payment Pending';
    final badgeIcon = isConfirmed ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'DELIVERED',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(badgeIcon, size: 13, color: badgeColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: badgeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route: compact two-line format
          Text(
            pickupParsed.city,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: primaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Icon(Icons.arrow_downward_rounded,
                size: 14, color: secondaryText.withValues(alpha: 0.5)),
          ),
          Text(
            dropParsed.city,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: primaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Budget + provider
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.budget.isNotEmpty
                      ? LoadFormatters.formatBudget(trip.budget)
                      : 'Budget N/A',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  trip.providerName,
                  style: TextStyle(fontSize: 12, color: secondaryText),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Payment settlement — shown for every delivered trip
          const SizedBox(height: 12),
          paymentState.when(
            data: (paymentData) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaymentStatusCard(
                  payment: paymentData,
                  load: trip,
                  currentUser: ref.read(authStateProvider).value!,
                  isDark: widget.isDark,
                ),
                if (paymentData != null && paymentData.status == 'confirmed') ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isUpdating ? null : () => _advanceStatusForLoad(trip, TripStatus.completed),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('COMPLETE TRIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => Text(
              'Error loading payment state.',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

}
