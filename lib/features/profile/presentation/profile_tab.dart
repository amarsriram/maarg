import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/safe_parse_utils.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await ref.read(authControllerProvider.notifier).logout();
      
      if (!mounted) return;
      
      // GoRouter listens to authStateProvider and will automatically
      // redirect to /login and handle widget unmounting cleanly.
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log out. Please try again.')),
        );
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.darkSurfaceCard, AppColors.darkSurface]
                        : [theme.primaryColor, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: StreamBuilder<DocumentSnapshot>(
                    // Fetch real user data from the 'users' collection
                    stream: user != null 
                      ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()
                      : const Stream.empty(),
                    builder: (context, snapshot) {
                      String displayName = user?.email?.split('@').first.toUpperCase() ?? 'LOGISTICS CO.';
                      String email = user?.email ?? 'Unknown User';
                      
                      if (snapshot.hasData && snapshot.data != null && snapshot.data?.exists == true) {
                        final rawData = snapshot.data?.data();
                        final data = (rawData as Map<String, dynamic>?) ?? {};
                        final nameRaw = SafeParse.safeString(data['companyName'] ?? data['name'], '');
                        if (nameRaw.isNotEmpty) {
                          displayName = nameRaw;
                        }
                      }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Text(
                                displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('ACCOUNT', theme, isDark),
                  const SizedBox(height: 12),
                  _buildSettingsCard([
                    _buildSettingsTile(Icons.person_outline, 'Company Details', isDark),
                    _buildDivider(isDark),
                    _buildSettingsTile(Icons.payments_outlined, 'Payment Methods', isDark),
                    _buildDivider(isDark),
                    _buildSettingsTile(Icons.receipt_long_outlined, 'Billing History', isDark),
                  ], isDark),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('PREFERENCES', theme, isDark),
                  const SizedBox(height: 12),
                  _buildSettingsCard([
                    _buildSettingsTile(Icons.notifications_outlined, 'Notifications', isDark),
                    _buildDivider(isDark),
                    _buildSettingsTile(Icons.language_outlined, 'Language', isDark, trailing: 'English'),
                  ], isDark),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle('SUPPORT', theme, isDark),
                  const SizedBox(height: 12),
                  _buildSettingsCard([
                    _buildSettingsTile(Icons.help_outline, 'Help Center', isDark),
                    _buildDivider(isDark),
                    _buildSettingsTile(Icons.privacy_tip_outlined, 'Privacy Policy', isDark),
                  ], isDark),

                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoggingOut ? null : _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text(
                                  'Log Out',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 100), // Padding for floating nav
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, bool isDark, {String? trailing}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Flexible(
                child: Text(
                  trailing,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (trailing != null) const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          ],
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      color: isDark ? AppColors.darkDivider : Colors.grey.shade100,
    );
  }
}
