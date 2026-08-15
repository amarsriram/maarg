import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/models/load_model.dart';
import '../../../../core/repositories/load_repository.dart';
import '../../../auth/data/auth_repository.dart';

class PostLoadTab extends ConsumerStatefulWidget {
  const PostLoadTab({super.key});

  @override
  ConsumerState<PostLoadTab> createState() => _PostLoadTabState();
}

class _PostLoadTabState extends ConsumerState<PostLoadTab> {
  final _formKey = GlobalKey<FormState>();
  
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _materialController = TextEditingController();
  final _truckTypeController = TextEditingController();
  final _weightController = TextEditingController();
  final _budgetController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isPublishing = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _materialController.dispose();
    _truckTypeController.dispose();
    _weightController.dispose();
    _budgetController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _publishLoad() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not found. Please relogin.')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final repo = ref.read(loadRepositoryProvider);
      final newLoad = LoadModel(
        loadId: const Uuid().v4(),
        providerUid: user.id,
        providerName: user.providerDisplayName,
        pickupLocation: _pickupController.text.trim(),
        dropLocation: _dropController.text.trim(),
        materialType: _materialController.text.trim(),
        truckType: _truckTypeController.text.trim(),
        weight: '${_weightController.text.trim()} Tons',
        budget: '₹${_budgetController.text.trim()}',
        pickupDate: _dateController.text.trim(),
        notes: _notesController.text.trim(),
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.createLoad(newLoad);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Load published successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _formKey.currentState!.reset();
        
        // Optionally clear controllers manually
        _pickupController.clear();
        _dropController.clear();
        _materialController.clear();
        _truckTypeController.clear();
        _weightController.clear();
        _budgetController.clear();
        _dateController.clear();
        _notesController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish load: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          'Post New Load',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Route Details', isDark: isDark),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _pickupController,
                  label: 'Pickup Location',
                  hintText: 'e.g. Mumbai, MH',
                  prefixIcon: const Icon(Icons.circle_outlined, size: 20, color: AppColors.primaryBlue),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _dropController,
                  label: 'Drop Location',
                  hintText: 'e.g. Delhi NCR',
                  prefixIcon: const Icon(Icons.location_on, size: 20, color: AppColors.error),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 32),
                
                _SectionHeader(title: 'Load Details', isDark: isDark),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _materialController,
                  label: 'Material Type',
                  hintText: 'e.g. Steel Pipes, FMCG',
                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CustomTextField(
                        controller: _truckTypeController,
                        label: 'Truck Type',
                        hintText: 'e.g. Flatbed',
                        prefixIcon: const Icon(Icons.local_shipping_outlined, size: 20),
                        textInputAction: TextInputAction.next,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: CustomTextField(
                        controller: _weightController,
                        label: 'Weight (Tons)',
                        hintText: '20',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _SectionHeader(title: 'Logistics', isDark: isDark),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _budgetController,
                        label: 'Budget (₹)',
                        hintText: '18000',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                        textInputAction: TextInputAction.next,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: _dateController,
                        label: 'Pickup Date',
                        hintText: 'e.g. Tomorrow, 8 PM',
                        prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
                        textInputAction: TextInputAction.next,
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _notesController,
                  label: 'Special Instructions (Optional)',
                  hintText: 'e.g. Needs tarpaulin covering',
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                  textInputAction: TextInputAction.done,
                ),
                
                const SizedBox(height: 48),
                CustomButton(
                  text: 'Publish Load',
                  onPressed: _isPublishing ? null : _publishLoad,
                  isLoading: _isPublishing,
                ),
                const SizedBox(height: 100), // padding for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isDark});
  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
