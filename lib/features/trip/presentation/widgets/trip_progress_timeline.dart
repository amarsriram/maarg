import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/trip_status.dart';

class TripProgressTimeline extends StatelessWidget {
  final TripStatus currentStatus;
  final bool isDark;

  const TripProgressTimeline({
    super.key,
    required this.currentStatus,
    required this.isDark,
  });

  // Define the main operational stages for the timeline
  static const List<TripStatus> _stages = [
    TripStatus.assigned,
    TripStatus.en_route_pickup,
    TripStatus.loaded,
    TripStatus.in_transit,
    TripStatus.delivered,
    TripStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    if (currentStatus == TripStatus.open || currentStatus == TripStatus.requested || currentStatus == TripStatus.cancelled) {
      return const SizedBox.shrink(); // Hide timeline for pre-trip or cancelled states
    }

    final currentIndex = _stages.indexOf(currentStatus);
    // If disputed but previously in a stage, we might want to highlight it red, 
    // but for simplicity, we'll just show the last known good stage if it's not in the list.
    final effectiveIndex = currentIndex >= 0 ? currentIndex : _stages.length - 1;

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
          Text(
            'Trip Progression',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_stages.length, (index) {
            final stage = _stages[index];
            final isCompleted = index < effectiveIndex || (currentStatus == TripStatus.completed && index == effectiveIndex);
            final isCurrent = index == effectiveIndex && currentStatus != TripStatus.completed;
            final isLast = index == _stages.length - 1;

            return _buildTimelineStep(
              stage: stage,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required TripStatus stage,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final Color activeColor = currentStatus == TripStatus.disputed 
        ? AppColors.error 
        : AppColors.primaryBlue;

    final Color color = isCompleted || isCurrent 
        ? activeColor 
        : (isDark ? Colors.white24 : Colors.black26);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? activeColor : Colors.transparent,
                border: Border.all(
                  color: color,
                  width: isCurrent ? 3 : 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : (isCurrent
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeColor,
                            ),
                          ),
                        )
                      : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isCompleted ? activeColor : (isDark ? Colors.white12 : Colors.black12),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCompleted || isCurrent
                        ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                        : (isDark ? Colors.white54 : AppColors.lightTextTertiary),
                  ),
                ),
                if (isCurrent && currentStatus == TripStatus.disputed)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Trip is currently disputed. Contact support.',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  )
                else if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Current active stage',
                      style: TextStyle(
                        fontSize: 12,
                        color: activeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (currentStatus == TripStatus.completed && isLast)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (!isLast) const SizedBox(height: 20), // Spacing matches line height
              ],
            ),
          ),
        ),
      ],
    );
  }
}
