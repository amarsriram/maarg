import re

with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add missing imports
if "package:firebase_core/firebase_core.dart" not in content:
    content = content.replace("import 'package:flutter/material.dart';", 
                              "import 'package:flutter/material.dart';\nimport 'package:firebase_core/firebase_core.dart';")

# 2. Fix requestLoad to requestBooking (line 404 roughly)
content = content.replace(".requestLoad(widget.load, user)", ".requestBooking(widget.load, user)")

# 3. Restore _buildLoadErrorHome if missing
if "_buildLoadErrorHome(bool isDark) {" not in content:
    error_home = """  // ── Error: Firestore/provider failure — NEVER shown as empty ────────────
  Widget _buildLoadErrorHome(bool isDark) {
    final labelColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final bodyColor  = isDark ? Colors.white54 : Colors.black54;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 36,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'UNABLE TO LOAD MARKETPLACE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: bodyColor, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {}),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                    ),
                    child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

"""
    # Insert before _buildActiveTripHome
    content = content.replace("  Widget _buildActiveTripHome(", error_home + "  Widget _buildActiveTripHome(")

with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)
