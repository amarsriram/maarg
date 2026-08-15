import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_shimmer.dart';

class MaargLoadCardSkeleton extends StatelessWidget {
  final bool isDark;

  const MaargLoadCardSkeleton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 175,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: status pill + route summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomShimmer(
                width: 50,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
              CustomShimmer(
                width: 100,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),

          const Spacer(),

          // Hero: city name
          CustomShimmer(
            width: 220,
            height: 20,
            borderRadius: BorderRadius.circular(4),
          ),

          const SizedBox(height: 12),

          // Compatibility line + pickup time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomShimmer(
                width: 150,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
              CustomShimmer(
                width: 80,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),

          const Spacer(),

          // CTA button
          CustomShimmer(
            width: double.infinity,
            height: 40,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}
