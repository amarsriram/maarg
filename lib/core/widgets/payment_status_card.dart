import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../models/load_model.dart';
import '../models/payment_model.dart';
import '../repositories/payment_repository.dart';
import '../../features/auth/domain/user_model.dart';

class PaymentStatusCard extends ConsumerStatefulWidget {
  final PaymentModel? payment;
  final LoadModel load;
  final AppUser currentUser;
  final bool isDark;

  const PaymentStatusCard({
    super.key,
    required this.payment,
    required this.load,
    required this.currentUser,
    required this.isDark,
  });

  @override
  ConsumerState<PaymentStatusCard> createState() => _PaymentStatusCardState();
}

class _PaymentStatusCardState extends ConsumerState<PaymentStatusCard> {
  bool _isLoading = false;

  Future<void> _handleAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action successful.'),
            backgroundColor: AppColors.success,
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = widget.currentUser.id == widget.load.providerUid;
    final payment = widget.payment;

    if (payment == null) {
      if (isProvider) {
        return _buildProviderMarkPaidAction();
      } else {
        return _buildTruckOwnerPendingView();
      }
    }

    switch (payment.status) {
      case 'marked_paid':
        if (isProvider) {
          return _buildProviderAwaitingConfirmationView();
        } else {
          return _buildTruckOwnerConfirmAction();
        }
      case 'confirmed':
        return _buildTerminalBanner('Payment Confirmed ✓', AppColors.success);
      case 'disputed':
        return _buildTerminalBanner('Payment Disputed — Contact Support', AppColors.error);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProviderMarkPaidAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'PAYMENT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Did you complete the payment to the truck owner?',
            style: TextStyle(
              fontSize: 14,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () => _handleAction(() => ref
                    .read(paymentRepositoryProvider)
                    .markAsPaid(widget.load, widget.currentUser)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Mark as Paid', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckOwnerPendingView() {
    return _buildPillView(
      'AWAITING PAYMENT',
      'The provider has not marked the payment as paid yet.',
      AppColors.warning,
      Icons.hourglass_empty,
    );
  }

  Widget _buildProviderAwaitingConfirmationView() {
    return _buildPillView(
      'PAYMENT MARKED',
      'Awaiting truck owner confirmation.',
      AppColors.warning,
      Icons.access_time,
    );
  }

  Widget _buildTruckOwnerConfirmAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'PAYMENT RECEIVED?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'The provider marked the payment as complete. Did you receive the payment?',
            style: TextStyle(
              fontSize: 14,
              color: widget.isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _handleAction(() => ref
                          .read(paymentRepositoryProvider)
                          .disputePayment(widget.load.loadId, widget.currentUser)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Report Issue', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _handleAction(() => ref
                          .read(paymentRepositoryProvider)
                          .confirmPayment(widget.load.loadId, widget.currentUser)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalBanner(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(color == AppColors.success ? Icons.check_circle : Icons.error_outline, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillView(String title, String subtitle, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: widget.isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
