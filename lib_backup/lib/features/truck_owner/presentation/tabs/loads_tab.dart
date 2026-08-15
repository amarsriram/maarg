import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../../core/models/booking_model.dart';
import '../../../../core/repositories/booking_repository.dart';
import '../../../../core/services/trip_operations_service.dart';
import '../../../auth/data/auth_repository.dart';

class LoadsTab extends ConsumerWidget {
  const LoadsTab({super.key});

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

    final availableLoadsStream = ref.watch(availableLoadsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Available Loads',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: availableLoadsStream.when(
        data: (loads) {
          if (loads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    'No loads available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for new opportunities.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: loads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final load = loads[index];
              return _LoadOpportunityCard(load: load, isDark: isDark);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
        error: (err, stack) => Center(
          child: Text(
            'Error loading marketplace.\n$err',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}

class _LoadOpportunityCard extends ConsumerStatefulWidget {
  const _LoadOpportunityCard({required this.load, required this.isDark});

  final LoadModel load;
  final bool isDark;

  @override
  ConsumerState<_LoadOpportunityCard> createState() => _LoadOpportunityCardState();
}

class _LoadOpportunityCardState extends ConsumerState<_LoadOpportunityCard> {
  bool _isRequesting = false;

  Future<void> _requestLoad() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to request loads.')),
      );
      return;
    }

    setState(() => _isRequesting = true);

    try {
      await ref.read(tripOperationsServiceProvider).requestBooking(widget.load, user);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Load requested successfully! Waiting for provider approval.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('REQUEST LOAD FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _withdrawRequest(BookingModel booking) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isRequesting = true);

    try {
      await ref.read(tripOperationsServiceProvider).withdrawBooking(booking, user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request withdrawn'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('WITHDRAW FAILED: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
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

    // Reactively watch the booking state for this load + truck owner
    final bookingKey = user != null ? '${user.id}|${widget.load.loadId}' : '';
    final bookingState = user != null
        ? ref.watch(truckOwnerBookingForLoadProvider(bookingKey))
        : null;

    // Determine button state from booking
    final BookingModel? existingBooking = bookingState?.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.25), width: 0.5),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: AppColors.cyanAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                widget.load.budget,
                style: const TextStyle(
                  color: AppColors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.load.pickupLocation} → ${widget.load.dropLocation}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: widget.isDark ? Colors.white : AppColors.lightTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.load.weight} • ${widget.load.materialType}',
            style: TextStyle(
              fontSize: 13,
              color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? AppColors.darkBg.withValues(alpha: 0.5) : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                const SizedBox(width: 6),
                Text(
                  widget.load.pickupDate,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.load.truckType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildBookingButton(existingBooking),
        ],
      ),
    );
  }

  Widget _buildBookingButton(BookingModel? existingBooking) {
    if (existingBooking == null) {
      // No booking exists — show "Request Load"
      return SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _isRequesting ? null : _requestLoad,
          style: TextButton.styleFrom(
            backgroundColor: widget.isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.primaryBlue.withValues(alpha: 0.05),
            foregroundColor: AppColors.primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isRequesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                )
              : const Text(
                  'Request Load',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
        ),
      );
    }

    // Booking exists — determine state
    final status = existingBooking.status;

    switch (status) {
      case 'pending':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isRequesting ? null : () => _withdrawRequest(existingBooking),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isRequesting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_outlined, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Withdraw Request',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
          ),
        );

      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: null,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.success.withValues(alpha: 0.08),
              disabledForegroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Text(
                  'Assigned',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                ),
              ],
            ),
          ),
        );

      case 'rejected':
        return SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isRequesting ? null : _requestLoad,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.08),
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Rejected',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
