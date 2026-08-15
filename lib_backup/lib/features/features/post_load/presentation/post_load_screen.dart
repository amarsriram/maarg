import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class LoadPost {
  final String pickupLocation;
  final String dropLocation;
  final String truckType;
  final double price;
  final DateTime createdAt;

  const LoadPost({
    required this.pickupLocation,
    required this.dropLocation,
    required this.truckType,
    required this.price,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'truckType': truckType,
      'price': price,
      'status': 'OPEN',
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class LoadService {
  final FirebaseFirestore _firestore;

  LoadService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> postLoad(LoadPost load) async {
    await _firestore.collection('loads').add(load.toFirestore());
  }
}

const List<String> _truckTypes = [
  'Open Body',
  'Closed Container',
  'Flatbed',
  'Refrigerated',
  'Tanker',
  'Tipper',
  'Mini Truck',
  'Trailer',
];

class PostLoadScreen extends StatefulWidget {
  const PostLoadScreen({super.key});

  @override
  State<PostLoadScreen> createState() => _PostLoadScreenState();
}

class _PostLoadScreenState extends State<PostLoadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedTruckType;
  bool _isSubmitting = false;

  final _loadService = LoadService();

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedTruckType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a truck type')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final load = LoadPost(
        pickupLocation: _pickupController.text.trim(),
        dropLocation: _dropController.text.trim(),
        truckType: _selectedTruckType ?? 'Unknown',
        price: double.parse(_priceController.text.trim()),
        createdAt: DateTime.now(),
      );

      await _loadService.postLoad(load);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Load posted successfully!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      _formKey.currentState?.reset();
      _pickupController.clear();
      _dropController.clear();
      _priceController.clear();
      setState(() => _selectedTruckType = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to post load: $e')),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a Load'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroBanner(colorScheme, isDark),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel(
                              icon: Icons.route_rounded,
                              label: 'Route Details',
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _pickupController,
                              label: 'Pickup Location',
                              hint: 'e.g. Mumbai, Maharashtra',
                              icon: Icons.my_location_rounded,
                              colorScheme: colorScheme,
                              isDark: isDark,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Enter pickup location' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _dropController,
                              label: 'Drop Location',
                              hint: 'e.g. Delhi, NCR',
                              icon: Icons.location_on_rounded,
                              colorScheme: colorScheme,
                              isDark: isDark,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Enter drop location' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel(
                              icon: Icons.local_shipping_rounded,
                              label: 'Load Information',
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 16),
                            _buildTruckTypeDropdown(colorScheme, isDark),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _priceController,
                              label: 'Price (₹)',
                              hint: 'e.g. 25000',
                              icon: Icons.currency_rupee_rounded,
                              colorScheme: colorScheme,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter a price';
                                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      _buildSubmitButton(colorScheme, isDark),
                      const SizedBox(height: 100), // padding for floating nav
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(ColorScheme colorScheme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkSurfaceCard, AppColors.darkSurface]
              : [AppColors.primaryBlue, const Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.25 : 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.add_road_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Shipment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Post your load details to find available trucks.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel({
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ColorScheme colorScheme,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceCard
            : colorScheme.primary.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        errorMaxLines: 3, // Prevent overflow on long errors
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),
    );
  }

  Widget _buildTruckTypeDropdown(ColorScheme colorScheme, bool isDark) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedTruckType,
      decoration: InputDecoration(
        labelText: 'Truck Type',
        hintText: 'Select truck type',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: Icon(Icons.local_shipping_rounded,
              size: 20, color: colorScheme.primary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceCard
            : colorScheme.primary.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      dropdownColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
      borderRadius: BorderRadius.circular(14),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
      items: _truckTypes
          .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedTruckType = value),
      validator: (v) => v == null ? 'Select a truck type' : null,
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isSubmitting
              ? LinearGradient(colors: [
                  colorScheme.primary.withValues(alpha: 0.5),
                  colorScheme.primary.withValues(alpha: 0.35),
                ])
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isSubmitting
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.publish_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Post Load',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
