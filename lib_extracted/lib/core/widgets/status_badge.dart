import 'package:flutter/material.dart';

enum StatusType { open, pending, inTransit, delivered, error }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case StatusType.open:
        color = const Color(0xFF10B981); // Premium Emerald Green
        break;
      case StatusType.pending:
        color = const Color(0xFF06B6D4); // Premium Cyan (Clean operational state)
        break;
      case StatusType.inTransit:
        color = const Color(0xFF1677FF); // Maarg Electric Blue
        break;
      case StatusType.delivered:
        color = const Color(0xFF0D9488); // Deep Teal
        break;
      case StatusType.error:
        color = const Color(0xFFEF4444); // Premium Red
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
