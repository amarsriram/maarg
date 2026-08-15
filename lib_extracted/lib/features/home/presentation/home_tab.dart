import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/safe_parse_utils.dart';
import '../../../core/utils/string_utils.dart';
import '../../../core/widgets/custom_shimmer.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final user = authState.value;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Simply delay to allow the stream to rebuild or let UI feel responsive
          await Future.delayed(const Duration(milliseconds: 800));
        },
        color: theme.primaryColor,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.person, color: theme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Good morning,",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        user.email.split('@').first.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),
            
            // StreamBuilder controls the entire body so we can derive metrics
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('loads')
                  .where('userId', isEqualTo: user?.id)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      const ShimmerListSkeleton(),
                    ]),
                  );
                }

                if (snapshot.hasError) {
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Center(
                          child: Text("Error loading data: ${snapshot.error}"),
                        ),
                      ),
                    ]),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                
                // Validate loads fields exist safely before rendering (Phase 6)
                final loads = allDocs.where((doc) {
                  final raw = doc.data();
                  final data = (raw as Map<String, dynamic>?) ?? {};
                  return SafeParse.isValidLoad(data);
                }).toList();
                
                // Calculate dynamic metrics from real data
                final totalLoads = loads.length;
                int openBodyCount = 0;
                int containerCount = 0;
                
                for (var doc in loads) {
                  final docData = doc.data();
                  final docMap = (docData as Map<String, dynamic>?) ?? {};
                  final type = SafeParse.safeString(docMap['truckType'], '').toLowerCase();
                  if (type.contains('open')) openBodyCount++;
                  if (type.contains('container')) containerCount++;
                }

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // Real Metrics Section
                    _buildMetricsSection(theme, isDark, totalLoads, openBodyCount, containerCount),
                    
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Live Loads",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text("View All"),
                          ),
                        ],
                      ),
                    ),
                    
                    // List or Empty State
                    if (loads.isEmpty)
                      _buildEmptyState(theme, isDark)
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
                        child: Column(
                          children: loads.map((doc) {
                            final raw = doc.data();
                            final data = (raw as Map<String, dynamic>?) ?? {};
                            return _buildModernLoadCard(data, theme, isDark);
                          }).toList(),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(ThemeData theme, bool isDark, int totalLoads, int openBody, int containers) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _MetricCard(
            title: "Total Loads",
            value: totalLoads.toString(),
            icon: Icons.local_shipping,
            color: AppColors.primaryBlue,
            isDark: isDark,
          ),
          _MetricCard(
            title: "Open Body",
            value: openBody.toString(),
            icon: Icons.view_headline,
            color: AppColors.primaryLight,
            isDark: isDark,
          ),
          _MetricCard(
            title: "Containers",
            value: containers.toString(),
            icon: Icons.inventory_2_outlined,
            color: AppColors.cyanAccent,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            "No Loads Posted Yet",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: isDark ? Colors.grey.shade400 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Post your first shipment load.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade600 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoadCard(Map<String, dynamic> data, ThemeData theme, bool isDark) {
    final pickupRaw = SafeParse.safeString(data['pickupLocation'] ?? data['from'], 'Unknown');
    final dropRaw = SafeParse.safeString(data['dropLocation'] ?? data['to'], 'Unknown');
    
    // Use StringUtils to properly capitalize cities
    final pickup = StringUtils.capitalizeWords(pickupRaw);
    final drop = StringUtils.capitalizeWords(dropRaw);
    
    final type = SafeParse.safeString(data['truckType'], 'Any Type');
    
    // Use CurrencyUtils to format the price properly (e.g. ₹25,000)
    final priceFormatted = CurrencyUtils.formatINR(data['price'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Open",
                    style: TextStyle(
                      color: AppColors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  priceFormatted,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.cyanAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Column(
                  children: [
                    Icon(Icons.circle_outlined, size: 14, color: theme.primaryColor),
                    Container(
                      height: 30,
                      width: 2,
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),
                    const Icon(Icons.location_on, size: 14, color: AppColors.accentOrange),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        drop,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
