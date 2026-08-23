import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../repositories/contact_exchange_repository.dart';
import 'contact_exchange_card.dart';

/// A confirmation dialog shown immediately after a booking is accepted.
/// Reuses [ContactExchangeCard] to display the authoritative contact securely.
class ContactExchangeSuccessDialog extends ConsumerWidget {
  final String bookingId;
  final String currentUserUid;
  final VoidCallback onViewAction;
  final String viewActionLabel;
  final String title;
  final String subtitle;

  const ContactExchangeSuccessDialog({
    super.key,
    required this.bookingId,
    required this.currentUserUid,
    required this.onViewAction,
    required this.viewActionLabel,
    this.title = 'Booking Accepted',
    this.subtitle = 'Contact exchanged successfully.',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final exchangeAsync = ref.watch(contactExchangeProvider(bookingId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title & Subtitle
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              // The Authoritative Contact Exchange Card
              exchangeAsync.when(
                data: (exchange) => ContactExchangeCard(
                  currentUserUid: currentUserUid,
                  exchange: exchange,
                ),
                loading: () => ContactExchangeCard(
                  currentUserUid: currentUserUid,
                  exchange: null, // Safe locked fallback while loading
                ),
                error: (err, stack) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Contact exchange is being updated.',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // View Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onViewAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    viewActionLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              // Close Button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
