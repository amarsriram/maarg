import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/load_model.dart';
import '../models/load_request_state.dart';
import '../utils/load_formatters.dart';

/// Canonical load decision card.
///
/// Pure presentation component — no Riverpod, no Firestore, no business logic.
/// All state and callbacks are supplied by the parent composition layer.
///
/// Six semantic layers (top → bottom):
///   1. Operational Status pill + State-code route summary
///   2. Route hero — origin city with dot indicator
///   3. Route hero — destination city with dot indicator
///   4. Pickup row
///   5. Compatibility line
///   6. Primary action button
class MaargLoadCard extends StatelessWidget {
  final LoadModel load;
  final LoadRequestState requestState;
  final bool isDark;

  /// Opens Load Details. Entire card surface is also tappable.
  final VoidCallback onTap;

  /// Executes the booking action appropriate for [requestState].
  /// Determined exclusively by the parent.
  final VoidCallback onPrimaryAction;

  const MaargLoadCard({
    super.key,
    required this.load,
    required this.requestState,
    required this.isDark,
    required this.onTap,
    required this.onPrimaryAction,
  });

  // ── Derived display values ─────────────────────────────────────────────
  
  ParsedLocation get _pickupParsed {
    final parsed = LoadFormatters.parseLocation(load.pickupLocation);
    final detailsCity = load.pickupLocationDetails?.city ?? '';
    final detailsState = load.pickupLocationDetails?.state ?? '';
    return ParsedLocation(
      city: detailsCity.isNotEmpty ? detailsCity : parsed.city,
      state: detailsState.isNotEmpty ? detailsState : parsed.state,
      stateCode: detailsState.isNotEmpty ? LoadFormatters.stateCode(detailsState) : parsed.stateCode,
    );
  }

  ParsedLocation get _dropParsed {
    final parsed = LoadFormatters.parseLocation(load.dropLocation);
    final detailsCity = load.dropLocationDetails?.city ?? '';
    final detailsState = load.dropLocationDetails?.state ?? '';
    return ParsedLocation(
      city: detailsCity.isNotEmpty ? detailsCity : parsed.city,
      state: detailsState.isNotEmpty ? detailsState : parsed.state,
      stateCode: detailsState.isNotEmpty ? LoadFormatters.stateCode(detailsState) : parsed.stateCode,
    );
  }

  String get _pickupCity => _pickupParsed.city;
  String get _pickupState => _pickupParsed.state;
  String get _dropCity => _dropParsed.city;
  String get _dropState => _dropParsed.state;

  String get _stateCodeSummary {
    final pickupCode = _pickupParsed.stateCode;
    final dropCode = _dropParsed.stateCode;

    if (pickupCode.isEmpty && dropCode.isEmpty) return '—';
    if (pickupCode.isEmpty) return dropCode;
    if (dropCode.isEmpty) return pickupCode;
    if (pickupCode == dropCode) return pickupCode;

    return '$pickupCode → $dropCode';
  }
  String get _pickupFormatted => LoadFormatters.formatPickupDate(load.pickupDate);
  String get _compatibility =>
      LoadFormatters.formatCompatibilityLine(load.materialType, load.weight, load.truckType);

  // ── Colors ─────────────────────────────────────────────────────────────
  Color get _primaryText =>
      isDark ? Colors.white : AppColors.lightTextPrimary;
  Color get _secondaryText =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get _tertiaryText =>
      isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
  Color get _surface =>
      isDark ? AppColors.darkSurface : Colors.white;
  Color get _border =>
      isDark ? AppColors.darkBorder : AppColors.lightBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primaryBlue.withValues(alpha: 0.06),
          highlightColor: AppColors.primaryBlue.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Layer 1: Status pill + State-code summary ──────────
                _LayerStatusRow(
                  status: load.status,
                  stateCodeSummary: _stateCodeSummary,
                  isDark: isDark,
                  secondaryText: _secondaryText,
                  tertiaryText: _tertiaryText,
                ),

                const SizedBox(height: 10),

                // ── Layer 2 & 3: Route hero ────────────────────────────
                _LayerRoute(
                  pickupCity: _pickupCity,
                  pickupState: _pickupState,
                  dropCity: _dropCity,
                  dropState: _dropState,
                  primaryText: _primaryText,
                  secondaryText: _secondaryText,
                  isDark: isDark,
                ),

                const SizedBox(height: 10),

                // ── Layer 4: Pickup row ────────────────────────────────
                _LayerPickup(
                  formatted: _pickupFormatted,
                  primaryText: _primaryText,
                  tertiaryText: _tertiaryText,
                ),

                const SizedBox(height: 8),

                // ── Layer 5: Compatibility line ────────────────────────
                Text(
                  _compatibility,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _tertiaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // ── Layer 5b: Budget row ───────────────────────────────
                _LayerBudget(
                  budget: load.budget,
                  primaryText: _primaryText,
                  tertiaryText: _tertiaryText,
                ),

                const SizedBox(height: 12),

                // ── Layer 6: Primary action ────────────────────────────
                _LayerAction(
                  requestState: requestState,
                  onPrimaryAction: onPrimaryAction,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  LAYER 1 — Operational Status + State-code Summary
// ══════════════════════════════════════════════════════════════════════════

class _LayerStatusRow extends StatelessWidget {
  const _LayerStatusRow({
    required this.status,
    required this.stateCodeSummary,
    required this.isDark,
    required this.secondaryText,
    required this.tertiaryText,
  });

  final String status;
  final String stateCodeSummary;
  final bool isDark;
  final Color secondaryText;
  final Color tertiaryText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatusPill(status: status),
        Text(
          stateCodeSummary,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tertiaryText,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status.trim().isEmpty ? 'OPEN' : status.toUpperCase();

    Color color;
    switch (label) {
      case 'URGENT':
        color = AppColors.warning;
        break;
      case 'ASSIGNED':
      case 'COMPLETED':
        color = AppColors.success;
        break;
      case 'EXPIRED':
        color = Colors.grey;
        break;
      default:
        color = AppColors.primaryBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  LAYERS 2 & 3 — Route Hero
// ══════════════════════════════════════════════════════════════════════════

class _LayerRoute extends StatelessWidget {
  const _LayerRoute({
    required this.pickupCity,
    required this.pickupState,
    required this.dropCity,
    required this.dropState,
    required this.primaryText,
    required this.secondaryText,
    required this.isDark,
  });

  final String pickupCity;
  final String pickupState;
  final String dropCity;
  final String dropState;
  final Color primaryText;
  final Color secondaryText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot–line–dot vertical indicator
          _RouteIndicator(isDark: isDark),
          const SizedBox(width: 10),
          // City + State labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CityLabel(
                    city: pickupCity, state: pickupState,
                    primaryText: primaryText, secondaryText: secondaryText),
                const SizedBox(height: 6),
                _CityLabel(
                    city: dropCity, state: dropState,
                    primaryText: primaryText, secondaryText: secondaryText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteIndicator extends StatelessWidget {
  const _RouteIndicator({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dotColor = AppColors.primaryBlue;
    final lineColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Origin dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        // Dashed connector
        Expanded(
          child: CustomPaint(
            painter: _DashedLinePainter(color: lineColor),
            child: const SizedBox(width: 1),
          ),
        ),
        // Destination dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: 1.5),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dashHeight = 3.0;
    const dashSpace = 3.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

class _CityLabel extends StatelessWidget {
  const _CityLabel({
    required this.city,
    required this.state,
    required this.primaryText,
    required this.secondaryText,
  });

  final String city;
  final String state;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          city,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: primaryText,
            letterSpacing: -0.3,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (state.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            state,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  LAYER 4 — Pickup Row
// ══════════════════════════════════════════════════════════════════════════

class _LayerPickup extends StatelessWidget {
  const _LayerPickup({
    required this.formatted,
    required this.primaryText,
    required this.tertiaryText,
  });

  final String formatted;
  final Color primaryText;
  final Color tertiaryText;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Pickup',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tertiaryText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            formatted,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  LAYER 5b — Budget Row
// ══════════════════════════════════════════════════════════════════════════

class _LayerBudget extends StatelessWidget {
  const _LayerBudget({
    required this.budget,
    required this.primaryText,
    required this.tertiaryText,
  });

  final String budget;
  final Color primaryText;
  final Color tertiaryText;

  @override
  Widget build(BuildContext context) {
    final hasBudget = budget.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Budget',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tertiaryText,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hasBudget ? LoadFormatters.formatBudget(budget) : 'Not set',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: hasBudget ? primaryText : tertiaryText,
              letterSpacing: hasBudget ? -0.2 : 0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  LAYER 6 — Primary Action
// ══════════════════════════════════════════════════════════════════════════

class _LayerAction extends StatelessWidget {
  const _LayerAction({
    required this.requestState,
    required this.onPrimaryAction,
    required this.isDark,
  });

  final LoadRequestState requestState;
  final VoidCallback onPrimaryAction;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    switch (requestState) {
      case LoadRequestState.none:
        return _ActionButton(
          label: 'Request Load',
          onPressed: onPrimaryAction,
          fgColor: Colors.white,
          bgColor: AppColors.primaryBlue,
        );

      case LoadRequestState.pending:
        return _ActionButton(
          label: 'Requested · Tap to Cancel',
          onPressed: onPrimaryAction,
          fgColor: AppColors.warning,
          bgColor: AppColors.warning.withValues(alpha: 0.08),
          outlined: true,
        );

      case LoadRequestState.accepted:
        return _ActionButton(
          label: 'View Trip',
          onPressed: onPrimaryAction,
          fgColor: AppColors.success,
          bgColor: AppColors.success.withValues(alpha: 0.08),
        );

      case LoadRequestState.rejected:
        return _ActionButton(
          label: 'Rejected · Request Again',
          onPressed: onPrimaryAction,
          fgColor: AppColors.error,
          bgColor: AppColors.error.withValues(alpha: 0.07),
        );

      case LoadRequestState.withdrawn:
        return _ActionButton(
          label: 'Request Load',
          onPressed: onPrimaryAction,
          fgColor: Colors.white,
          bgColor: AppColors.primaryBlue,
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.fgColor,
    required this.bgColor,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Color fgColor;
  final Color bgColor;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 34,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fgColor,
            side: BorderSide(color: fgColor.withValues(alpha: 0.4)),
            shape: shape,
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: fgColor,
          backgroundColor: bgColor,
          shape: shape,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
