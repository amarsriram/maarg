import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// RouteVisualizer renders a premium visual indicator for cargo or truck routes.
/// It shows a starting node (origin), a connection line (with a moving truck icon concept),
/// and an ending node (destination), styled beautifully for light and dark modes.
class RouteVisualizer extends StatelessWidget {
  final String origin;
  final String destination;
  final String? originSubtitle;
  final String? destinationSubtitle;
  final bool isCompact;

  const RouteVisualizer({
    super.key,
    required this.origin,
    required this.destination,
    this.originSubtitle,
    this.destinationSubtitle,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primaryBlue;
    final accentColor = AppColors.accentOrange;

    if (isCompact) {
      return Row(
        children: [
          Icon(Icons.radio_button_checked, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Text(
            origin,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 14, color: theme.hintColor),
          const SizedBox(width: 8),
          Icon(Icons.location_on, size: 16, color: accentColor),
          const SizedBox(width: 4),
          Text(
            destination,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Visual Dots and Connective Line
        Column(
          children: [
            const SizedBox(height: 4),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor,
                  width: 3,
                ),
                color: Colors.transparent,
              ),
            ),
            Container(
              width: 2,
              height: 32,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              child: Center(
                child: Icon(
                  Icons.local_shipping_outlined,
                  size: 12,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            Icon(
              Icons.location_on,
              size: 18,
              color: accentColor,
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Right Column: Address and Route Names
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Origin block
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    origin,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (originSubtitle != null)
                    Text(
                      originSubtitle ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Destination block
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (destinationSubtitle != null)
                    Text(
                      destinationSubtitle ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
