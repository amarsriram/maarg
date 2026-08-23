import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location_model.dart';
import '../constants/app_colors.dart';

class RichLocationCard extends StatelessWidget {
  final String label; // "PICKUP" or "DELIVERY"
  final String fallbackAddress;
  final LocationModel? locationDetails;
  final bool isDark;

  const RichLocationCard({
    super.key,
    required this.label,
    required this.fallbackAddress,
    required this.locationDetails,
    required this.isDark,
  });

  Future<void> _navigate(BuildContext context, double lat, double lng) async {
    // We do NOT use canLaunchUrl() as a gate. On Android 11+ (API 30+),
    // resolveActivity()-based checks return null for packages not visible to
    // us, causing false negatives even when Google Maps or a browser is
    // installed. launchUrl() itself uses startActivity() which does not
    // require package-visibility declarations and handles failure gracefully.
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final geoUri = Uri(scheme: 'geo', path: '$lat,$lng', query: 'q=$lat,$lng');

    try {
      // First: open in Google Maps / system browser (any https handler).
      final launchedMaps = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
      if (launchedMaps) return;

      // Second fallback: generic geo: intent for native map apps.
      final launchedGeo = await launchUrl(
        geoUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedGeo) return;

      // Both failed — no maps/browser handler present on this device.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No maps app available to handle this request.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Gracefully ignore launcher errors to prevent crash.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkSurfaceCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final hasDetails = locationDetails != null;
    final lat = locationDetails?.latitude;
    final lng = locationDetails?.longitude;
    final canNavigate = hasDetails && lat != null && lng != null;

    final displayName = hasDetails && locationDetails!.displayName.isNotEmpty
        ? locationDetails!.displayName
        : fallbackAddress;

    final List<Widget> hierarchyTags = [];
    if (hasDetails) {
      if (locationDetails!.locality?.isNotEmpty == true) hierarchyTags.add(_buildTag('Locality: ${locationDetails!.locality}'));
      if (locationDetails!.city.isNotEmpty) hierarchyTags.add(_buildTag('City: ${locationDetails!.city}'));
      if (locationDetails!.district.isNotEmpty) hierarchyTags.add(_buildTag('District: ${locationDetails!.district}'));
      if (locationDetails!.state.isNotEmpty) hierarchyTags.add(_buildTag('State: ${locationDetails!.state}'));
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                  letterSpacing: 0.8,
                ),
              ),
              if (canNavigate)
                InkWell(
                  onTap: () => _navigate(context, lat, lng),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.navigation_outlined, size: 14, color: AppColors.primaryBlue),
                      const SizedBox(width: 4),
                      const Text(
                        'Navigate',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              height: 1.3,
            ),
          ),
          if (hierarchyTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hierarchyTags,
            ),
          ],
          if (canNavigate) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
