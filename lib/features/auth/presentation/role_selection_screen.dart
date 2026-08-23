import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../domain/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_controller.dart';
import 'package:flutter/foundation.dart';


class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.none;
  bool _isSaving = false;

  Future<void> _handleContinue() async {
    if (_selectedRole == UserRole.none || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        return;
      }

      final success = await ref.read(authControllerProvider.notifier).selectRole(_selectedRole);
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save role. Please try again.'), backgroundColor: AppColors.error),
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("ROLE SAVE ERROR: $e");
      }
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF031B4E) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1220) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: Image.asset(
                    'assets/images/maarg_logo.png',
                    width: 56,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Choose Your Workspace',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select how you\'ll use Maarg',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : AppColors.lightTextTertiary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // Card 1 — Load Provider
              _buildWorkspaceCard(
                role: UserRole.provider,
                icon: Icons.inventory_2_outlined,
                title: 'Load Provider',
                description:
                    'Post and manage shipments across India',
                preview:
                    'Operations Dashboard  •  Shipment Tracking  •  Fleet Booking',
                isDark: isDark,
                theme: theme,
              ),
              const SizedBox(height: 16),

              // Card 2 — Truck Owner / Driver
              _buildWorkspaceCard(
                role: UserRole.truckOwner,
                icon: Icons.local_shipping_outlined,
                title: 'Truck Owner / Driver',
                description:
                    'Find loads and manage active trips efficiently',
                preview:
                    'Live Loads  •  Trip Console  •  Route Management',
                isDark: isDark,
                theme: theme,
              ),

              const Spacer(),

              // Continue
              CustomButton(
                text: 'Continue',
                onPressed: (_selectedRole != UserRole.none && !_isSaving) ? _handleContinue : null,
                isLoading: _isSaving,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String description,
    required String preview,
    required bool isDark,
    required ThemeData theme,
  }) {
    final isSelected = _selectedRole == role;
    const activeColor = Color(0xFF1677FF);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? const Color(0xFF0B1220)
                  : const Color(0xFFF0F7FF))
              : (isDark
                  ? const Color(0xFF0A1628)
                  : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.12)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? activeColor
                        : (isDark ? Colors.white54 : Colors.grey.shade600),
                    size: 22,
                  ),
                ),
                const Spacer(),
                // Check indicator
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            // Dashboard preview chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                preview,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.white38 : Colors.grey.shade500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
