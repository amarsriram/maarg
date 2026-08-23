import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/models/load_request_state.dart';
import '../../../../core/models/trip_status.dart';
import '../../../../core/utils/load_formatters.dart';
import '../../../../core/widgets/maarg_load_card_skeleton.dart';
import '../models/driver_home_state.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/repositories/analytics_repository.dart';
import '../../../../core/repositories/booking_repository.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/services/trip_operations_service.dart';
import '../../../../core/widgets/maarg_load_card.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../notifications/presentation/notification_feed_screen.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';
import '../../../dashboard/presentation/load_detail_screen.dart';
import '../../../../core/widgets/contact_exchange_success_dialog.dart';

class TruckOwnerHomeTab extends ConsumerStatefulWidget {
  const TruckOwnerHomeTab({super.key, this.onTabChange});
  final Function(int)? onTabChange;

  @override
  ConsumerState<TruckOwnerHomeTab> createState() => _TruckOwnerHomeTabState();
}

class _TruckOwnerHomeTabState extends ConsumerState<TruckOwnerHomeTab> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 22) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user != null) {
      ref.listen<AsyncValue<BookingModel?>>(
        truckOwnerActiveBookingProvider(user.id),
        (previous, next) {
          final prevBooking = previous?.value;
          final nextBooking = next.value;
          
          if (prevBooking != null && prevBooking.status == 'pending' && nextBooking != null && nextBooking.status == 'accepted') {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => ContactExchangeSuccessDialog(
                bookingId: '${nextBooking.loadId}_${user.id}',
                currentUserUid: user.id,
                title: 'Booking Accepted',
                subtitle: 'Your contact has been exchanged\nwith the Provider.',
                onViewAction: () {
                  Navigator.pop(ctx);
                  widget.onTabChange?.call(1); // Navigate to Trips Tab
                },
                viewActionLabel: 'View Trip',
              ),
            );
          }
        },
      );
    }

    final availableLoadsStream = ref.watch(availableLoadsProvider);
    final activeTripsStream = user != null ? ref.watch(truckOwnerTripsProvider(user.id)) : const AsyncValue<List<LoadModel>>.data([]);

    // 1. Resolve State — distinguish loading / error / empty / data
    DriverHomeState state = DriverHomeState.loading;
    List<LoadModel>? loads;
    LoadModel? activeTrip;
    bool hasLoadError = false;
    bool hasTripError = false;

    if (availableLoadsStream.isLoading || activeTripsStream.isLoading) {
      state = DriverHomeState.loading;
    } else if (activeTripsStream.hasError) {
      hasTripError = true;
      state = DriverHomeState.activeTrip;
    } else if (availableLoadsStream.hasError) {
      // Real error — must NOT appear as empty marketplace
      hasLoadError = true;
      state = DriverHomeState.emptyMarketplace; // re-used slot; hasLoadError flag distinguishes
    } else {
      final trips = activeTripsStream.value ?? [];
      
      // Priority 1: Genuine operational trip
      activeTrip = trips.where((t) => t.tripStatus.isOperational).firstOrNull;
      
      loads = availableLoadsStream.value ?? [];

      if (activeTrip != null) {
        state = DriverHomeState.activeTrip;
      } else {
        // Priority 2: Pending Request
        // We need to check if there is a pending booking or a trip that is requested
        // Let's use the truckOwnerActiveBookingProvider to check for pending requests
        final pendingBooking = user != null ? ref.watch(truckOwnerActiveBookingProvider(user.id)).valueOrNull : null;
        
        if (pendingBooking != null && pendingBooking.status == 'pending') {
          state = DriverHomeState.pendingRequests;
        } else if (loads.isNotEmpty) {
          state = DriverHomeState.idle;
        } else {
          state = DriverHomeState.emptyMarketplace;
        }
      }
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildDriverHeader(isDark, user),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _buildOperationalWorkspace(isDark, user?.id, loads?.length ?? 0, state),
          ),
        ),
        hasLoadError
            ? _buildLoadErrorHome(isDark)
            : _buildStateWorkspace(state, isDark, loads, activeTrip, hasTripError, user != null ? ref.watch(truckOwnerActiveBookingProvider(user.id)).valueOrNull : null),
      ],
    );
  }

  Widget _buildStateWorkspace(DriverHomeState state, bool isDark, List<LoadModel>? loads, LoadModel? activeTrip, bool hasTripError, BookingModel? pendingBooking) {
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
        if (pendingBooking == null) return _buildLoadingHome(isDark);
        return _buildPendingRequestsHome(isDark, pendingBooking);
    }
  }

  Widget _buildLoadingHome(bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: MaargLoadCardSkeleton(isDark: isDark),
          ),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildIdleHome(bool isDark, List<LoadModel> loads) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == loads.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 120),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      if (widget.onTabChange != null) {
                        widget.onTabChange!(1);
                      }
                    },
                    child: const Text(
                      'View More Loads  →',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(text: 'Available Loads', isDark: isDark),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LoadCardComposer(load: loads[0], isDark: isDark),
                  ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LoadCardComposer(load: loads[index], isDark: isDark),
            );
          },
          childCount: loads.length + 1,
        ),
      ),
    );
  }

  Widget _buildEmptyMarketplaceHome(bool isDark) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'No open loads available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll automatically show new loads\nmatching your vehicle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Last refreshed $timeStr',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {}); 
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            )
          ],
        ),
      ),
    );
  }

  // ── Error: Firestore/provider failure — NEVER shown as empty ────────────
  Widget _buildLoadErrorHome(bool isDark) {
    final labelColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final bodyColor  = isDark ? Colors.white54 : Colors.black54;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 36,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'UNABLE TO LOAD MARKETPLACE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: bodyColor, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {}),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                    ),
                    child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripHome(bool isDark, LoadModel trip) {
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
  }

  Widget _buildPendingRequestsHome(bool isDark, BookingModel booking) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REQUEST PENDING',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Route motif
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Column(
                            children: [
                              const SizedBox(height: 6),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? Colors.white30 : Colors.black26, width: 2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 1.5,
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.pickupLocation,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 36),
                                Text(
                                  booking.dropLocation,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'Waiting for provider to review your request.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _withdrawRequestFromHome(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Withdraw Request',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
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
  
  bool _isWithdrawing = false;
  Future<void> _withdrawRequestFromHome(BookingModel booking) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    
    if (_isWithdrawing) return;
    setState(() => _isWithdrawing = true);
    
    try {
      await ref.read(tripOperationsServiceProvider).withdrawBooking(booking, user).timeout(const Duration(seconds: 8));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request withdrawn'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to withdraw: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  Widget _buildDriverHeader(bool isDark, user) {
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextSecondary,
              ),
            ),
            Flexible(
              child: Text(
                user?.driverDisplayName ?? 'Truck Driver',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: NotificationBadge(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationFeedScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalWorkspace(bool isDark, String? uid, int availableLoads, DriverHomeState state) {
    if (uid == null) {
      return _buildStaticWorkspace(isDark, 0, 0, availableLoads, state);
    }
    final analyticsAsync = ref.watch(truckOwnerAnalyticsProvider(uid));
    return analyticsAsync.when(
      data: (analytics) => _buildStaticWorkspace(isDark, analytics.weeklyEarnings, analytics.completedTrips, availableLoads, state),
      loading: () => _buildStaticWorkspace(isDark, 0, 0, availableLoads, state),
      error: (_, _) => _buildStaticWorkspace(isDark, 0, 0, availableLoads, state),
    );
  }

  Widget _buildStaticWorkspace(bool isDark, int earnings, int trips, int availableLoads, DriverHomeState state) {
    Color signalColor;
    String signalText;

    switch (state) {
      case DriverHomeState.idle:
      case DriverHomeState.emptyMarketplace:
        signalColor = AppColors.primaryBlue;
        signalText = 'AVAILABLE FOR NEW LOADS';
        break;
      case DriverHomeState.activeTrip:
        signalColor = AppColors.primaryBlue;
        signalText = 'ACTIVE TRIP';
        break;
      case DriverHomeState.pendingRequests:
        signalColor = AppColors.warning;
        signalText = 'REQUEST PENDING';
        break;
      case DriverHomeState.loading:
        signalColor = isDark ? Colors.white38 : Colors.black38;
        signalText = 'RESOLVING WORKSPACE...';
        break;
    }

    final lineColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildDot(signalColor),
            const SizedBox(width: 16),
            Text(
              signalText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: signalColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(left: 3.5),
          width: 1.5,
          height: 18,
          color: lineColor,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildDot(AppColors.primaryBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricsRow(isDark, earnings, trips, availableLoads),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 8.5,
      height: 8.5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark, int earnings, int trips, int availableLoads) {
    final eString = LoadFormatters.formatCompactInr(earnings);
    
    return Row(
      children: [
        Expanded(flex: 3, child: _buildMetricItem('EARNINGS', eString, isDark)),
        Expanded(flex: 2, child: _buildMetricItem('TRIPS', trips.toString(), isDark)),
        Expanded(flex: 2, child: _buildMetricItem('OPEN LOADS', availableLoads.toString(), isDark)),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  COMPOSER FOR MAARG LOAD CARD
// ════════════════════════════════════════════════════════════════════════

class _LoadCardComposer extends ConsumerStatefulWidget {
  const _LoadCardComposer({required this.load, required this.isDark});
  final LoadModel load;
  final bool isDark;

  @override
  ConsumerState<_LoadCardComposer> createState() => _LoadCardComposerState();
}

class _LoadCardComposerState extends ConsumerState<_LoadCardComposer> {
  bool _isRequesting = false;

  Future<void> _requestLoad() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isRequesting = true);

    try {
      await ref.read(tripOperationsServiceProvider).requestBooking(widget.load, user).timeout(const Duration(seconds: 8));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Load requested successfully! Waiting for provider approval.'),
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
            content: Text('Failed to request load: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _withdrawRequest(BookingModel booking) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isRequesting = true);

    try {
      await ref.read(tripOperationsServiceProvider).withdrawBooking(booking, user).timeout(const Duration(seconds: 8));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request withdrawn'),
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
            content: Text('Failed to withdraw request: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final bookingKey = user != null ? '${user.id}|${widget.load.loadId}' : '';
    final bookingState = user != null ? ref.watch(truckOwnerBookingForLoadProvider(bookingKey)) : null;
    
    final BookingModel? existingBooking = bookingState?.value;
    
    LoadRequestState requestState = LoadRequestState.none;
    VoidCallback onPrimaryAction = _requestLoad;

    if (_isRequesting) {
      // Keep state but don't perform action while loading (disabled callback)
      onPrimaryAction = () {}; 
    }

    if (existingBooking != null) {
      switch (existingBooking.status) {
        case 'pending':
          requestState = LoadRequestState.pending;
          onPrimaryAction = _isRequesting ? () {} : () => _withdrawRequest(existingBooking);
          break;
        case 'accepted':
          requestState = LoadRequestState.accepted;
          onPrimaryAction = () {
            // View Trip logic can be added here or delegate to parent
          };
          break;
        case 'rejected':
          requestState = LoadRequestState.rejected;
          onPrimaryAction = _isRequesting ? () {} : _requestLoad;
          break;
        case 'withdrawn':
          requestState = LoadRequestState.withdrawn;
          onPrimaryAction = _isRequesting ? () {} : _requestLoad;
          break;
      }
    }

    return MaargLoadCard(
      load: widget.load,
      requestState: requestState,
      isDark: widget.isDark,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoadDetailScreen(
              loadId: widget.load.loadId,
              initialLoad: widget.load,
            ),
          ),
        );
      },
      onPrimaryAction: onPrimaryAction,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS
// ════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}



class _ActiveTripWorkspace extends ConsumerStatefulWidget {
  const _ActiveTripWorkspace({
    required this.trip,
    required this.isDark,
    this.onTabChange,
  });

  final LoadModel trip;
  final bool isDark;
  final Function(int)? onTabChange;

  @override
  ConsumerState<_ActiveTripWorkspace> createState() => _ActiveTripWorkspaceState();
}

class _ActiveTripWorkspaceState extends ConsumerState<_ActiveTripWorkspace> {
  bool _isUpdating = false;

  Color get _statusColor {
    switch (widget.trip.tripStatus) {
      case TripStatus.assigned:
        return AppColors.info;
      case TripStatus.en_route_pickup:
      case TripStatus.loaded:
      case TripStatus.in_transit:
        return AppColors.primaryBlue;
      case TripStatus.delivered:
        return AppColors.warning;
      case TripStatus.completed:
        return AppColors.success;
      default:
        return widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    }
  }

  String get _statusLabel {
    return widget.trip.tripStatus.displayName.toUpperCase();
  }

  (TripStatus, String)? get _nextAction {
    switch (widget.trip.tripStatus) {
      case TripStatus.assigned:
        return (TripStatus.en_route_pickup, 'Confirm Departure');
      case TripStatus.en_route_pickup:
        return (TripStatus.loaded, 'Mark Loaded');
      case TripStatus.loaded:
        return (TripStatus.in_transit, 'Start Transit');
      case TripStatus.in_transit:
        return (TripStatus.delivered, 'Mark Delivered');
      default:
        return null;
    }
  }

  /// Short contextual sentence for the Next Move section.
  /// Derived strictly from existing trip states — never fabricated.
  String? get _nextMoveContext {
    switch (widget.trip.tripStatus) {
      case TripStatus.assigned:
        return 'Your load is assigned and ready to begin.';
      case TripStatus.en_route_pickup:
        return 'Head to the pickup location to collect the cargo.';
      case TripStatus.loaded:
        return 'Cargo is loaded. Begin transit to the destination.';
      case TripStatus.in_transit:
        return 'You\'re on the way. Mark delivered on arrival.';
      default:
        return null;
    }
  }


  Future<void> _advanceStatus(TripStatus nextStatus) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isUpdating = true);
    try {
      await ref.read(tripOperationsServiceProvider).advanceLoadStatus(widget.trip, nextStatus, user).timeout(const Duration(seconds: 8));
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
            content: Text(e.toString().replaceAll('Exception: ', '')),
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
    final borderColor = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primaryText = widget.isDark ? Colors.white : AppColors.darkBg;
    final tertiaryText = widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surfaceColor = widget.isDark ? AppColors.darkSurface : Colors.white;

    final originState = LoadFormatters.extractState(widget.trip.pickupLocation);
    final destState = LoadFormatters.extractState(widget.trip.dropLocation);
    // Preserve exact provider-selected location — no normalization
    final originCity = widget.trip.pickupLocation.split(',').first.trim();
    final destCity = widget.trip.dropLocation.split(',').first.trim();

    final action = _nextAction;
    final contextSentence = _nextMoveContext;

    return GestureDetector(
      // Tapping non-button area of this card navigates to the Trips tab (index 2).
      // Button widgets (TextButton, ElevatedButton) absorb their own pointer events
      // in Flutter and do NOT bubble to this GestureDetector.
      behavior: HitTestBehavior.translucent,
      onTap: () => widget.onTabChange?.call(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── ● ACTIVE TRIP — operational signal ─────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ACTIVE TRIP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12), // small intentional gap

          // ── ROUTE ──────────────────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vertical motif column
                SizedBox(
                  width: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6), // align with top of origin city
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 1.5, // restrained connector line
                            color: widget.isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Push bottom node up to align with dest city, leaving state text below it
                      SizedBox(height: destState.isNotEmpty ? 18 : 6),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Location labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Origin
                      Text(
                        originCity,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (originState.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            originState,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tertiaryText,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Destination
                      Text(
                        destCity,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (destState.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            destState,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tertiaryText,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Status chip + pickup date (inline, subordinate) ────────────────
          const SizedBox(height: 20), // moderate gap
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.20)),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LoadFormatters.formatPickupDate(widget.trip.pickupDate),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tertiaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // ── NEXT MOVE ──────────────────────────────────────────────────────
          if (action != null) ...[
            const SizedBox(height: 20), // moderate gap

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NEXT MOVE label
                  Text(
                    'NEXT MOVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tertiaryText,
                      letterSpacing: 0.7,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Action name — prominent
                  Text(
                    action.$2.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                      letterSpacing: 0.2,
                      height: 1.15,
                    ),
                  ),

                  // Contextual sentence — if available
                  if (contextSentence != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      contextSentence,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: tertiaryText,
                        height: 1.45,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Primary CTA — absorbs its own tap; does NOT bubble to the GestureDetector
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _isUpdating ? null : () => _advanceStatus(action.$1),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primaryBlue.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              action.$2,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── VIEW TRIP — secondary action (also absorbs its own tap) ────────
          const SizedBox(height: 12), // small/moderate gap
          Center(
            child: TextButton(
              onPressed: () => widget.onTabChange?.call(2),
              style: TextButton.styleFrom(
                foregroundColor: widget.isDark ? Colors.white54 : Colors.black45,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'VIEW TRIP →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
