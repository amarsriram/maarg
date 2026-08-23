import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../models/contact_exchange_model.dart';
import 'premium_card.dart';

/// ContactExchangeCard
///
/// Displays the contact exchange status for a completed booking.
/// Security model mirrors Firestore rules — phone numbers are ONLY rendered
/// when [exchange.status == 'accepted']. All other states show a locked UI.
///
/// PRIVACY:
///   The current user's own phone is never shown as a contact.
///   [currentUserUid] determines which party's phone is "the other party".
///
/// PHONE ACTIONS:
///   Phase 2A provides a UI-level callback [onCallPressed] so the caller
///   controls the action (e.g. launch a native dialer). No VoIP or telecom
///   dependency is introduced here.
class ContactExchangeCard extends StatelessWidget {
  /// The current authenticated user's UID — used to determine role.
  final String currentUserUid;

  /// The deserialized contact exchange document, or null if not yet created.
  final ContactExchangeModel? exchange;

  /// Called with the other party's phone number when the user taps Call.
  /// Only invoked when [exchange.status == 'accepted'].
  final void Function(String phone)? onCallPressed;

  /// Called with the other party's phone number when the user taps Copy.
  /// Only invoked when [exchange.status == 'accepted'].
  final void Function(String phone)? onCopyPressed;

  const ContactExchangeCard({
    super.key,
    required this.currentUserUid,
    required this.exchange,
    this.onCallPressed,
    this.onCopyPressed,
  });

  /// Resolves which phone number belongs to the OTHER party.
  /// Returns null if the exchange is not yet accepted or the phone is absent.
  String? _otherPartyPhone() {
    if (exchange == null) return null;
    if (exchange!.status != 'accepted') return null;

    // Truck Owner sees Provider's phone; Provider sees Truck Owner's phone.
    if (currentUserUid == exchange!.truckOwnerUid) {
      return exchange!.providerPhone;
    } else if (currentUserUid == exchange!.providerUid) {
      return exchange!.truckOwnerPhone;
    }
    // Unrecognized UID — show nothing as a safe default.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = exchange?.status ?? 'pending';

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark, status),
          const SizedBox(height: 16),
          _buildBody(context, isDark, status),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, String status) {
    return Row(
      children: [
        _buildStatusIcon(isDark, status),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact Exchange',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              _buildStatusLabel(isDark, status),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(bool isDark, String status) {
    final Color bgColor;
    final Color iconColor;
    final IconData icon;

    switch (status) {
      case 'accepted':
        bgColor = AppColors.success.withValues(alpha: 0.12);
        iconColor = AppColors.success;
        icon = Icons.verified_rounded;
        break;
      case 'withdrawn':
        bgColor = AppColors.error.withValues(alpha: 0.10);
        iconColor = AppColors.error;
        icon = Icons.lock_outline_rounded;
        break;
      case 'pending':
      default:
        bgColor = AppColors.primaryBlue.withValues(alpha: 0.10);
        iconColor = AppColors.primaryBlue;
        icon = Icons.lock_clock_outlined;
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  Widget _buildStatusLabel(bool isDark, String status) {
    final String label;
    final Color color;

    switch (status) {
      case 'accepted':
        label = 'Contact Exchanged';
        color = AppColors.success;
        break;
      case 'withdrawn':
        label = 'Contact Exchange Closed';
        color = AppColors.error;
        break;
      case 'pending':
      default:
        label = 'Contact Protected';
        color = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        break;
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, String status) {
    switch (status) {
      case 'accepted':
        return _buildAcceptedBody(context, isDark);
      case 'withdrawn':
        return _buildWithdrawnBody(isDark);
      case 'pending':
      default:
        return _buildPendingBody(isDark);
    }
  }

  Widget _buildPendingBody(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceCard
            : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Contact details will be available after the booking is accepted.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedBody(BuildContext context, bool isDark) {
    final phone = _otherPartyPhone();

    if (phone == null || phone.isEmpty) {
      // Phone resolved to empty — safe fallback (should not occur in normal flow).
      return _buildPendingBody(isDark);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.phone_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  phone,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.call_rounded,
                label: 'Call',
                color: AppColors.success,
                // Use caller-supplied callback if provided; otherwise default to native dialer.
                onTap: onCallPressed != null
                    ? () => onCallPressed!(phone)
                    : () => _defaultCall(context, phone),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                color: AppColors.primaryBlue,
                onTap: onCopyPressed != null
                    ? () => onCopyPressed!(phone)
                    : () => _defaultCopy(context, phone),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWithdrawnBody(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, size: 16, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This booking request was withdrawn. Contact details are not available.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Default copy action when [onCopyPressed] is not provided.
  void _defaultCopy(BuildContext context, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Phone number copied'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Default call action when [onCallPressed] is not provided.
  /// Opens the native phone dialer without placing the call automatically.
  /// Silently ignores empty, null, or unlaunchable URIs.
  Future<void> _defaultCall(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri);
      } else {
        // Dialer unavailable (e.g. tablet with no phone app) — silent no-op.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No phone app available on this device.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      // Swallow unexpected launcher errors — never crash the UI.
    }
  }
}

// ── Internal action button ────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? color.withValues(alpha: 0.9) : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
