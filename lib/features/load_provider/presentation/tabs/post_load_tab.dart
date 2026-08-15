import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/location_selector_bottom_sheet.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../auth/data/auth_repository.dart';

final repostLoadProvider = StateProvider<LoadModel?>((ref) => null);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TruckCard {
  final String value;    // Backend value â€” must match AppConstants.truckTypes
  final IconData icon;
  final String description;
  const _TruckCard({required this.value, required this.icon, required this.description});
}

const List<_TruckCard> _truckCards = [
  _TruckCard(value: 'Mini Truck',    icon: Icons.airport_shuttle_outlined, description: 'Up to 1 ton'),
  _TruckCard(value: 'Pickup',        icon: Icons.directions_car_outlined,  description: 'Light loads'),
  _TruckCard(value: 'LCV',           icon: Icons.local_shipping_outlined,  description: '1â€“3.5 tons'),
  _TruckCard(value: 'Open Body',     icon: Icons.view_in_ar_outlined,      description: 'Bulk goods'),
  _TruckCard(value: 'Closed Body',   icon: Icons.inventory_2_outlined,     description: 'Protected cargo'),
  _TruckCard(value: 'Container',     icon: Icons.business_outlined,        description: 'Large shipments'),
  _TruckCard(value: 'Trailer',       icon: Icons.rv_hookup_outlined,       description: 'Heavy haulage'),
  _TruckCard(value: 'Flatbed',       icon: Icons.table_rows_outlined,      description: 'Oversized loads'),
  _TruckCard(value: 'Tanker',        icon: Icons.water_drop_outlined,      description: 'Liquids / gas'),
  _TruckCard(value: 'Tipper',        icon: Icons.construction_outlined,    description: 'Sand / gravel'),
  _TruckCard(value: 'Other',         icon: Icons.more_horiz_outlined,      description: 'Specify type'),
];

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PostLoadTab widget
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class PostLoadTab extends ConsumerStatefulWidget {
  const PostLoadTab({super.key, this.onTabChange});
  final Function(int)? onTabChange;

  @override
  ConsumerState<PostLoadTab> createState() => _PostLoadTabState();
}

class _PostLoadTabState extends ConsumerState<PostLoadTab> {
  // Step controller â€” 0 = Route & Timing, 1 = Load Details
  int _currentStep = 0;

  // â”€â”€ Form keys (one per step for precise validation) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  // â”€â”€ Controllers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _pickupController      = TextEditingController();
  final _dropController        = TextEditingController();
  final _pickupDateController  = TextEditingController(); // replaces _dateController
  final _deliveryDateController = TextEditingController();
  final _materialController    = TextEditingController();
  final _truckTypeController   = TextEditingController();
  final _truckOtherController  = TextEditingController();
  final _weightController      = TextEditingController();
  final _budgetController      = TextEditingController();
  final _notesController       = TextEditingController();

  // â”€â”€ Focus nodes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _pickupNode       = FocusNode();
  final _dropNode         = FocusNode();
  final _materialNode     = FocusNode();
  final _truckOtherNode   = FocusNode();
  final _weightNode       = FocusNode();
  final _budgetNode       = FocusNode();

  // â”€â”€ Derived state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  LocationModel? _pickupLocation;
  LocationModel? _dropLocation;
  bool _isTruckOther = false;   // true when "Other" truck card selected

  // â”€â”€ Submission guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _isPublishing = false;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Lifecycle
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();
    // Catch any repost value that was already set before this widget was built
    // (e.g. when the tab is first visited from ShipmentsTab).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(repostLoadProvider);
      if (pending != null) _applyRepost(pending);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _pickupController, _dropController, _pickupDateController,
      _deliveryDateController, _materialController, _truckTypeController,
      _truckOtherController, _weightController, _budgetController, _notesController,
    ]) { c.dispose(); }
    for (final n in [_pickupNode, _dropNode, _materialNode, _truckOtherNode, _weightNode, _budgetNode]) {
      n.dispose();
    }
    super.dispose();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // ── Repost helper ────────────────────────────────────────────────────────

  /// Populates the editable form controllers from [source] and immediately
  /// clears the provider so subsequent normal openings remain blank.
  /// Never restores loadId, status, createdAt, bookings, or assignments.
  void _applyRepost(LoadModel source) {
    if (!mounted) return;
    setState(() {
      // Step 1: Route & Timing
      _pickupController.text = source.pickupLocation;
      _dropController.text   = source.dropLocation;
      _pickupLocation        = source.pickupLocationDetails;  // nullable — OK
      _dropLocation          = source.dropLocationDetails;    // nullable — OK
      _pickupDateController.text   = '';  // force fresh date selection
      _deliveryDateController.text = '';

      // Step 2: Load Details
      _materialController.text = source.materialType;

      final knownTruck = AppConstants.truckTypes.contains(source.truckType);
      _truckTypeController.text  = knownTruck ? source.truckType : 'Other';
      _isTruckOther              = !knownTruck;
      _truckOtherController.text = knownTruck ? '' : source.truckType;

      _weightController.text = source.weight.replaceAll(RegExp(r'[^0-9.]'), '');
      _budgetController.text = source.budget.replaceAll(RegExp(r'[^0-9.]'), '');
      _notesController.text  = '';

      _currentStep = 0;
    });
    // Clear immediately — next normal opening must be blank.
    ref.read(repostLoadProvider.notifier).state = null;
  }

  void _resetForm() {
    _formKey1.currentState?.reset();
    _formKey2.currentState?.reset();
    for (final c in [
      _pickupController, _dropController, _pickupDateController,
      _deliveryDateController, _materialController, _truckTypeController,
      _truckOtherController, _weightController, _budgetController, _notesController,
    ]) { c.clear(); }
    _pickupLocation = null;
    _dropLocation = null;
    _isTruckOther = false;
    _currentStep = 0;
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Display helpers
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _formatDateDisplay(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]}, $h:$m $ampm';
    } catch (_) {
      return iso;
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Build
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  @override
  Widget build(BuildContext context) {
    // Repost flow: fires for subsequent triggers while this tab stays alive.
    // The initial trigger (first visit) is handled in initState via addPostFrameCallback.
    ref.listen<LoadModel?>(repostLoadProvider, (_, next) {
      if (next != null) _applyRepost(next);
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      // Removed appBar for custom header
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCustomHeader(theme, isDark),
            _buildStepper(theme, isDark),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: _currentStep > 0
                        ? const Offset(1, 0)
                        : const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
                child: _currentStep == 0
                    ? _buildStep1(theme, isDark, key: const ValueKey('step1'))
                    : _currentStep == 1
                        ? _buildStep2(theme, isDark, key: const ValueKey('step2'))
                        : _buildStep3(theme, isDark, key: const ValueKey('step3')),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────────────────────
  // Field actions
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _selectPickupDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (!mounted) return;
      if (time != null) {
        final full = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() => _pickupDateController.text = full.toIso8601String());
      }
    }
  }

  Future<void> _selectDeliveryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (!mounted) return;
      if (time != null) {
        final full = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() => _deliveryDateController.text = full.toIso8601String());
      }
    }
  }

  Future<void> _selectPickupLocation() async {
    final loc = await LocationSelectorBottomSheet.show(context, title: 'Pickup Location');
    if (!mounted) return;
    if (loc != null) {
      setState(() {
        _pickupLocation = loc;
        _pickupController.text = loc.displayName;
      });
    }
  }

  Future<void> _selectDropLocation() async {
    final loc = await LocationSelectorBottomSheet.show(context, title: 'Delivery Location');
    if (!mounted) return;
    if (loc != null) {
      setState(() {
        _dropLocation = loc;
        _dropController.text = loc.displayName;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Step navigation
  // ─────────────────────────────────────────────────────────────────────────────

  void _goNext() {
    FocusScope.of(context).unfocus();
    if (!_formKey1.currentState!.validate()) return;

    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    final pickupDate = _pickupDateController.text.trim();

    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup and delivery locations')),
      );
      return;
    }

    // Duplicate location check
    if (pickup.toLowerCase() == drop.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pickup and delivery locations cannot be the same')),
      );
      return;
    }

    if (pickupDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup date')),
      );
      return;
    }

    setState(() => _currentStep = 1);
  }

  void _goToReview() {
    FocusScope.of(context).unfocus();
    if (!_formKey2.currentState!.validate()) return;

    if (_materialController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select cargo type')),
      );
      return;
    }

    final w = double.tryParse(_weightController.text.trim());
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid weight')),
      );
      return;
    }

    final truckType = _isTruckOther
        ? _truckOtherController.text.trim()
        : _truckTypeController.text.trim();

    if (truckType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
      );
      return;
    }

    final b = double.tryParse(_budgetController.text.trim());
    if (b == null || b <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget (₹)')),
      );
      return;
    }

    setState(() => _currentStep = 2);
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = (_currentStep - 1).clamp(0, 2));
  }

  void _goToStep1() {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = 0);
  }

  void _goToStep2() {
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = 1);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Bottom sheet pickers
  // ─────────────────────────────────────────────────────────────────────────────

  void _showVehiclePicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select Vehicle', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _AnimatedTruckSelectionGrid(
              cards: _truckCards,
              selectedValue: _truckTypeController.text,
              isDark: isDark,
              onSelect: (value) {
                setState(() {
                  _truckTypeController.text = value;
                  _isTruckOther = value == 'Other';
                  if (!_isTruckOther) _truckOtherController.clear();
                });
                if (value != 'Other') {
                  Navigator.pop(ctx);
                }
              },
            ),
            if (_isTruckOther) ...[
              const SizedBox(height: 16),
              CustomTextField(
                controller: _truckOtherController,
                focusNode: _truckOtherNode,
                label: 'Specify Truck Type',
                hintText: 'e.g. Refrigerated truck',
                prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'SAVE',
                onPressed: () {
                  if (_truckOtherController.text.trim().length >= 2) {
                    setState(() {});
                    Navigator.pop(ctx);
                  }
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showWeightPicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Total Weight (Tons)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _WeightInputField(
              controller: _weightController,
              focusNode: _weightNode,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'SAVE',
              onPressed: () {
                setState(() {});
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetPicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Budget (₹)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _budgetController,
              focusNode: _budgetNode,
              label: 'Budget',
              hintText: 'e.g. 125000',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee_outlined, size: 20),
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final d = double.tryParse(v.trim());
                if (d == null || d <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'SAVE',
              onPressed: () {
                setState(() {});
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCargoPicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Material / Goods', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _materialController,
              focusNode: _materialNode,
              label: 'Material / Goods',
              hintText: 'Enter material...',
              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            _MaterialQuickChips(
              onSelected: (mat) {
                setState(() {
                  _materialController.text = mat;
                });
                Navigator.pop(ctx);
              },
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'SAVE',
              onPressed: () {
                setState(() {});
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishLoad() async {
    if (_isPublishing) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to post a load'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final repo = ref.read(loadRepositoryProvider);
      final truckType = _isTruckOther
          ? _truckOtherController.text.trim()
          : _truckTypeController.text.trim();

      final newLoad = LoadModel(
        loadId: '',
        providerUid: user.id,
        providerName: user.name ?? '',
        pickupLocation: _pickupController.text.trim(),
        dropLocation: _dropController.text.trim(),
        pickupLocationDetails: _pickupLocation,
        dropLocationDetails: _dropLocation,
        materialType: _materialController.text.trim(),
        truckType: truckType,
        weight: StringUtils.formatWeight(_weightController.text.trim()),
        budget: _budgetController.text.trim(),
        pickupDate: _pickupDateController.text.trim(),
        notes: _deliveryDateController.text.isNotEmpty
            ? 'deliveryDate:${_deliveryDateController.text.trim()}'
            : null,
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.createLoad(newLoad).timeout(const Duration(seconds: 15));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Load published successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _resetForm();
        widget.onTabChange?.call(0);
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection timed out. Please retry.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final message = e.code == 'unavailable'
            ? 'No internet connection. Please retry.'
            : 'Failed to publish: ${e.message}';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Widget _buildCustomHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  // E.g., pop navigation if needed, or reset form.
                  // For now, if step is > 0, go back, else do nothing.
                  if (_currentStep > 0) {
                    _goBack();
                  } else {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post a Load',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent, size: 14, color: AppColors.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  'Need help?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connecting lines
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  color: _currentStep >= 1 ? AppColors.primaryBlue : (isDark ? Colors.white24 : Colors.black12),
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: _currentStep >= 2 ? AppColors.primaryBlue : (isDark ? Colors.white24 : Colors.black12),
                ),
              ),
            ],
          ),
          // Nodes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepperNode(1, 'Route & Schedule', _currentStep >= 0, isDark),
              _buildStepperNode(2, 'Load Details', _currentStep >= 1, isDark),
              _buildStepperNode(3, 'Review & Publish', _currentStep >= 2, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperNode(int stepNum, String label, bool isActive, bool isDark) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primaryBlue : (isDark ? AppColors.darkBg : AppColors.lightBg),
            border: isActive ? null : Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 2),
            boxShadow: isActive ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 8)] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNum.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.primaryBlue : (isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      ],
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Step 1: Route & Timing â€” Unified Mission Control Card
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStep1(ThemeData theme, bool isDark, {required Key key}) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Form(
      key: _formKey1,
      child: Column(
        key: key,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Route Section Title
                    Text(
                      'Shipment Route',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Hero Route Workspace Component
                    MaargRouteWorkspace(
                      pickupController: _pickupController,
                      dropController: _dropController,
                      pickupHint: 'Select pickup city',
                      dropHint: 'Select delivery city',
                      isDark: isDark,
                      onPickupTap: _selectPickupLocation,
                      onDropTap: _selectDropLocation,
                    ),

                    const SizedBox(height: 20),

                    // Schedule Section Title
                    Text(
                      'Schedule',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date Cards Row â€” each card is full-width tappable
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _DateCard(
                              label: 'PICKUP DATE',
                              controller: _pickupDateController,
                              hint: 'Select date',
                              isDark: isDark,
                              onTap: _selectPickupDate,
                              formatDisplay: _formatDateDisplay,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Center(
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.darkSurfaceCard : Colors.grey.shade200,
                                ),
                                child: Icon(Icons.arrow_forward, size: 11, color: AppColors.primaryBlue),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _DateCard(
                              label: 'DELIVERY DATE',
                              controller: _deliveryDateController,
                              hint: 'Select date',
                              isDark: isDark,
                              onTap: _selectDeliveryDate,
                              formatDisplay: _formatDateDisplay,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Primary CTA â€” full-width, thumb-safe 56dp target
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _goNext,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade700, AppColors.primaryBlue],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Footer
                    // Removed draft UI
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Step 2: Load Details
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildStep2(ThemeData theme, bool isDark, {required Key key}) {
    return Form(
      key: _formKey2,
      child: Column(
        key: key,
        children: [
          // ── Scrollable content area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
              children: [
                // ── Compact Route Summary
                MaargCompactRouteSummary(
                  pickup: _pickupController.text,
                  drop: _dropController.text,
                  pickupDate: _formatDateDisplay(_pickupDateController.text),
                  deliveryDate: _formatDateDisplay(_deliveryDateController.text),
                  isDark: isDark,
                  onTap: _goBack,
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionLabel('Shipment Details', theme, isDark),
                ),
                const SizedBox(height: 12),
                
                // ── Shipment Details Workspace
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: MaargShipmentWorkspace(
                    cargoValue: _materialController.text,
                    weightValue: StringUtils.formatWeight(_weightController.text),
                    vehicleValue: _truckTypeController.text == 'Other' 
                        ? _truckOtherController.text 
                        : _truckTypeController.text,
                    budgetValue: _budgetController.text.trim(),
                    isDark: isDark,
                    onCargoTap: _showCargoPicker,
                    onWeightTap: _showWeightPicker,
                    onVehicleTap: _showVehiclePicker,
                    onBudgetTap: _showBudgetPicker,
                  ),
                ),
                
                const SizedBox(height: 48), // Bottom padding
              ],
            ),
          ),
          
          // ── Bottom CTA
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: CustomButton(
                text: 'CONTINUE',
                onPressed: _goToReview,
                isLoading: false,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────────────────────
  // Step 3: Review & Publish
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStep3(ThemeData theme, bool isDark, {required Key key}) {
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    final vehicleDisplay = _isTruckOther
        ? _truckOtherController.text.trim()
        : _truckTypeController.text.trim();

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // ── Section title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionLabel('Review Shipment', theme, isDark),
        ),
        const SizedBox(height: 14),

        // ── Review Workspace
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MaargReviewWorkspace(
            pickup: _pickupController.text,
            drop: _dropController.text,
            pickupDate: _formatDateDisplay(_pickupDateController.text),
            deliveryDate: _formatDateDisplay(_deliveryDateController.text),
            cargo: _materialController.text,
            weight: StringUtils.formatWeight(_weightController.text),
            vehicle: vehicleDisplay,
            budget: _budgetController.text.trim(),
            isDark: isDark,
            onRouteEdit: _goToStep1,
            onShipmentEdit: _goToStep2,
          ),
        ),

        const SizedBox(height: 16),

        // ── Additional Notes (only editable field on Step 3)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Additional notes (optional)',
                hintStyle: TextStyle(fontSize: 14, color: textSecondary),
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Footer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Visible to verified carriers after publishing.',
            style: TextStyle(fontSize: 12, color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ),

        // ── Publish CTA (absorbs keyboard inset)
        Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: bg,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: CustomButton(
                text: 'Publish Load',
                onPressed: _isPublishing ? null : _publishLoad,
                isLoading: _isPublishing,
              ),
            ),
          ),
        ),
      ],
    );
  }


}

/// Workspace for Step 2: Shipment Details
///
/// **Error State (Out of Scope for Initial Implementation)**
/// If field-level validation errors are needed in the future:
/// 1. Add `final String? errorText;` for each field or a unified `final String? formError;`
/// 2. If `formError != null`, change `activeBorderColor` to `theme.colorScheme.error`
/// 3. Display the error text below the component or inline using a warning icon.
/// For now, validation is handled at the form submission level (bottom CTA).
class MaargShipmentWorkspace extends StatelessWidget {
  final String cargoValue;
  final String weightValue;
  final String vehicleValue;
  final String budgetValue;
  final bool isDark;
  final VoidCallback onCargoTap;
  final VoidCallback onWeightTap;
  final VoidCallback onVehicleTap;
  final VoidCallback onBudgetTap;

  const MaargShipmentWorkspace({
    super.key,
    required this.cargoValue,
    required this.weightValue,
    required this.vehicleValue,
    required this.budgetValue,
    required this.isDark,
    required this.onCargoTap,
    required this.onWeightTap,
    required this.onVehicleTap,
    required this.onBudgetTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final hasCargo = cargoValue.isNotEmpty;
    final hasWeight = weightValue.isNotEmpty;
    final hasVehicle = vehicleValue.isNotEmpty;
    final hasBudget = budgetValue.isNotEmpty;
    final isComplete = hasCargo && hasWeight && hasVehicle && hasBudget;

    final activeBorderColor = isComplete ? AppColors.primaryBlue : borderColor;
    final activeBorderWidth = isComplete ? 1.5 : 1.2;

    Widget buildSlot({
      required String label,
      required String value,
      required String hint,
      required bool hasValue,
      required VoidCallback onTap,
      required bool isFirst,
      required bool isLast,
    }) {
      return Semantics(
        label: hasValue
            ? '$label: $value. Tap to change.'
            : '$label: not set. Tap to select.',
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isFirst ? 15 : 0),
              topRight: Radius.circular(isFirst ? 15 : 0),
              bottomLeft: Radius.circular(isLast ? 15 : 0),
              bottomRight: Radius.circular(isLast ? 15 : 0),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasValue ? value : hint,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
                            color: hasValue ? textPrimary : textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeBorderColor, width: activeBorderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSlot(
            label: 'CARGO',
            value: cargoValue,
            hint: 'Select cargo',
            hasValue: hasCargo,
            onTap: onCargoTap,
            isFirst: true,
            isLast: false,
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
          buildSlot(
            label: 'WEIGHT',
            value: weightValue,
            hint: 'Select weight',
            hasValue: hasWeight,
            onTap: onWeightTap,
            isFirst: false,
            isLast: false,
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
          buildSlot(
            label: 'VEHICLE',
            value: vehicleValue,
            hint: 'Select vehicle',
            hasValue: hasVehicle,
            onTap: onVehicleTap,
            isFirst: false,
            isLast: false,
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
          buildSlot(
            label: 'BUDGET',
            value: hasBudget ? '₹ $budgetValue' : '',
            hint: 'Enter budget (₹)',
            hasValue: hasBudget,
            onTap: onBudgetTap,
            isFirst: false,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final ThemeData theme;
  final bool isDark;
  const _SectionLabel(this.text, this.theme, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ── Compact Journey Banner ──────────────────────────────────────────────────


class MaargCompactRouteSummary extends StatelessWidget {
  final String pickup;
  final String drop;
  final String pickupDate;
  final String deliveryDate;
  final bool isDark;
  final VoidCallback onTap;

  const MaargCompactRouteSummary({
    super.key,
    required this.pickup,
    required this.drop,
    required this.pickupDate,
    required this.deliveryDate,
    required this.isDark,
    required this.onTap,
  });

  String _formatLocation(String raw) {
    if (raw.isEmpty) return 'Not set';
    return raw.split(',').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipment Route',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 20, bottom: 20, right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: CustomPaint(
                            painter: _RouteConnectorPainter(
                              color: borderColor,
                              dashed: pickup.isEmpty,
                            ),
                            size: const Size(2, double.infinity),
                          ),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: drop.isNotEmpty ? AppColors.primaryBlue : Colors.transparent,
                          border: Border.all(
                            color: drop.isNotEmpty
                                ? AppColors.primaryBlue
                                : textSecondary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 14, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatLocation(pickup),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: pickup.isEmpty ? textSecondary : textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Pickup',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pickupDate.isEmpty ? 'Not scheduled' : pickupDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: pickupDate.isEmpty ? FontWeight.w400 : FontWeight.w600,
                                    color: pickupDate.isEmpty ? textSecondary : textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: borderColor),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 14, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatLocation(drop),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: drop.isEmpty ? textSecondary : textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Delivery',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryBlue,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  deliveryDate.isEmpty ? 'Not scheduled' : deliveryDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: deliveryDate.isEmpty ? FontWeight.w400 : FontWeight.w600,
                                    color: deliveryDate.isEmpty ? textSecondary : textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


// ── Animated Truck Selection Grid ─────────────────────────────────────────────

class _AnimatedTruckSelectionGrid extends StatelessWidget {
  final List<_TruckCard> cards;
  final String selectedValue;
  final bool isDark;
  final void Function(String) onSelect;

  const _AnimatedTruckSelectionGrid({
    required this.cards,
    required this.selectedValue,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: cards.map((card) {
        final isSelected = selectedValue == card.value;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          child: OutlinedButton.icon(
            icon: Icon(card.icon, size: 18),
            label: Text(card.value),
            style: OutlinedButton.styleFrom(
              foregroundColor: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              backgroundColor: isSelected ? AppColors.primaryBlue : Colors.transparent,
              side: BorderSide(
                color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isSelected ? 1.5 : 1.0,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () => onSelect(card.value),
          ),
        );
      }).toList(),
    );
  }
}

// ── Weight Input Field ────────────────────────────────────────────────────────

class _WeightInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;

  const _WeightInputField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      label: 'Weight (Tons)',
      hintText: 'e.g. 18',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: const Icon(Icons.scale_outlined, size: 20),
      textInputAction: TextInputAction.next,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        final d = double.tryParse(v.trim());
        if (d == null || d <= 0) return 'Enter a valid weight';
        return null;
      },
    );
  }
}

// ── Material Quick Chips ──────────────────────────────────────────────────────

class _MaterialQuickChips extends StatelessWidget {
  final void Function(String) onSelected;
  final bool isDark;

  static const _materials = [
    'Steel', 'Cement', 'Sand', 'Bricks', 'Gravel',
    'Timber', 'Cotton', 'Chemicals', 'Electronics', 'Other',
  ];

  const _MaterialQuickChips({required this.onSelected, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _materials.map((mat) {
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => onSelected(mat),
          child: Text(mat, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }
}

// ── Date Card ─────────────────────────────────────────────────────────────────

class _DateCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final VoidCallback onTap;
  final String Function(String) formatDisplay;

  const _DateCard({
    required this.label,
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.onTap,
    required this.formatDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final hasValue = controller.text.isNotEmpty;
    final activeBorderColor = hasValue ? AppColors.primaryBlue : borderColor;
    final activeBorderWidth = hasValue ? 1.5 : 1.2;

    return Semantics(
      label: hasValue
          ? '$label: ${formatDisplay(controller.text)}. Tap to change.'
          : '$label: not set. Tap to select.',
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: activeBorderColor, width: activeBorderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? formatDisplay(controller.text) : hint,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
                          color: hasValue ? textPrimary : textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Maarg Route Workspace (Canonical Signature Component) ─────────────────────

/// Formats a raw location string to display city name only.
String _formatLocation(String raw) {
  return raw.split(',').first.trim();
}

/// Paints a vertical dashed or solid line for the route connector.
class _RouteConnectorPainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _RouteConnectorPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (!dashed) {
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
      return;
    }

    const dashHeight = 4.0;
    const gapHeight = 3.0;
    double startY = 0;
    final cx = size.width / 2;
    while (startY < size.height) {
      final endY = (startY + dashHeight).clamp(0.0, size.height);
      canvas.drawLine(Offset(cx, startY), Offset(cx, endY), paint);
      startY += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(_RouteConnectorPainter old) =>
      old.color != color || old.dashed != dashed;
}

class MaargRouteWorkspace extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropController;
  final String pickupHint;
  final String dropHint;
  final bool isDark;
  final VoidCallback onPickupTap;
  final VoidCallback onDropTap;

  const MaargRouteWorkspace({
    super.key,
    required this.pickupController,
    required this.dropController,
    required this.pickupHint,
    required this.dropHint,
    required this.isDark,
    required this.onPickupTap,
    required this.onDropTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final hasPickup = pickupController.text.isNotEmpty;
    final hasDrop = dropController.text.isNotEmpty;
    final isRouteComplete = hasPickup && hasDrop;

    final activeBorderColor = isRouteComplete ? AppColors.primaryBlue : borderColor;
    final activeBorderWidth = isRouteComplete ? 1.5 : 1.2;
    final connectorDashed = !hasPickup;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: activeBorderColor, width: activeBorderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 24, bottom: 24, right: 12),
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        painter: _RouteConnectorPainter(
                          color: borderColor,
                          dashed: connectorDashed,
                        ),
                        size: const Size(2, double.infinity),
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasDrop ? AppColors.primaryBlue : Colors.transparent,
                      border: Border.all(
                        color: hasDrop
                            ? AppColors.primaryBlue
                            : textSecondary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Semantics(
                    label: hasPickup
                        ? 'Pickup location: ${_formatLocation(pickupController.text)}. Tap to change.'
                        : 'Pickup location: not set. Tap to select.',
                    button: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: InkWell(
                        onTap: onPickupTap,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 14, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'PICKUP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hasPickup
                                          ? _formatLocation(pickupController.text)
                                          : pickupHint,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: hasPickup ? FontWeight.w700 : FontWeight.w400,
                                        color: hasPickup ? textPrimary : textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: textSecondary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: borderColor),
                  Semantics(
                    label: hasDrop
                        ? 'Delivery location: ${_formatLocation(dropController.text)}. Tap to change.'
                        : 'Delivery location: not set. Tap to select.',
                    button: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: InkWell(
                        onTap: onDropTap,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 14, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'DELIVERY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hasDrop
                                          ? _formatLocation(dropController.text)
                                          : dropHint,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: hasDrop ? FontWeight.w700 : FontWeight.w400,
                                        color: hasDrop ? textPrimary : textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: textSecondary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ── Review Workspace ──────────────────────────────────────────────────────────

/// Step 3 review component. Displays a single unified surface with two
/// sections (Route and Shipment) separated by a divider. Each section
/// has a tappable "Edit ›" affordance that navigates back to the
/// relevant step without any modals or bottom sheets.
class MaargReviewWorkspace extends StatelessWidget {
  // Route section
  final String pickup;
  final String drop;
  final String pickupDate;
  final String deliveryDate;

  // Shipment section
  final String cargo;
  final String weight;
  final String vehicle;
  final String budget;

  final bool isDark;
  final VoidCallback onRouteEdit;
  final VoidCallback onShipmentEdit;

  const MaargReviewWorkspace({
    super.key,
    required this.pickup,
    required this.drop,
    required this.pickupDate,
    required this.deliveryDate,
    required this.cargo,
    required this.weight,
    required this.vehicle,
    required this.budget,
    required this.isDark,
    required this.onRouteEdit,
    required this.onShipmentEdit,
  });

  String _city(String raw) {
    if (raw.isEmpty) return '—';
    return raw.split(',').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurfaceCard : Colors.white;

    Widget editLink(VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'Edit ›',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        );

    Widget sectionHeader(String title, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                  letterSpacing: 0.6,
                ),
              ),
              editLink(onTap),
            ],
          ),
        );

    // label on top (small muted), value below (larger bold) — vertical stack
    Widget dataRow(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: value.isEmpty ? textSecondary : textPrimary,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Route section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sectionHeader('SHIPMENT ROUTE', onRouteEdit),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _city(pickup),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '↓',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _city(drop),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Date column — fixed structure, no conditional height change
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Pickup',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          pickupDate.isEmpty ? 'Not scheduled' : pickupDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: pickupDate.isEmpty ? FontWeight.w400 : FontWeight.w700,
                            color: pickupDate.isEmpty ? textSecondary : textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Delivery',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          deliveryDate.isEmpty ? 'Not scheduled' : deliveryDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: deliveryDate.isEmpty ? FontWeight.w400 : FontWeight.w700,
                            color: deliveryDate.isEmpty ? textSecondary : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: borderColor),

          // ── Shipment section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sectionHeader('SHIPMENT DETAILS', onShipmentEdit),
                dataRow('Cargo', cargo),
                dataRow('Weight', weight),
                dataRow('Vehicle', vehicle),
                dataRow('Budget', budget.isNotEmpty ? '₹ $budget' : ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
