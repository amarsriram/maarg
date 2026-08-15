import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../auth/data/auth_repository.dart';
import '../../find_truck/domain/truck_model.dart';
import '../data/route_repository.dart';

class PostRouteScreen extends ConsumerStatefulWidget {
  const PostRouteScreen({super.key});

  @override
  ConsumerState<PostRouteScreen> createState() => _PostRouteScreenState();
}

class _PostRouteScreenState extends ConsumerState<PostRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sourceController = TextEditingController();
  final _destinationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  
  String _selectedTruckType = 'Container 20ft';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;

  final List<String> _truckTypes = [
    'Container 20ft',
    'Container 32ft MXL',
    'Open Body 19ft',
    'Flatbed Trailer 40ft',
    'Tata Ace / Chota Hathi',
    'Dumper Truck',
  ];

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isSubmitting = true;
    });

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final newRoute = TruckRoute(
      id: 'route-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: user.id,
      ownerName: user.driverDisplayName,
      companyName: user.companyName ?? 'Independent Owner',
      source: _sourceController.text.trim(),
      destination: _destinationController.text.trim(),
      date: _selectedDate,
      truckType: _selectedTruckType,
      capacity: double.tryParse(_capacityController.text.trim()) ?? 10.0,
      price: double.tryParse(_priceController.text.trim()) ?? 10000.0,
      vehicleNumber: _vehicleNumberController.text.trim().toUpperCase(),
      contactNumber: user.phoneNumber ?? '+91 99999 99999',
    );

    // Call Repository to Add Route
    await ref.read(routeRepositoryProvider.notifier).addRoute(newRoute);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      // Clear Form Fields
      _sourceController.clear();
      _destinationController.clear();
      _capacityController.clear();
      _priceController.clear();
      _vehicleNumberController.clear();
      
      // Show Success Dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              const SizedBox(width: 8),
              const Text('Route Posted Successfully'),
            ],
          ),
          content: const Text(
            'Your empty return truck route has been listed. Nearby suppliers will see this listing and book directly.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Return Route'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Callout Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primaryLight : AppColors.primaryBlue).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? AppColors.primaryLight : AppColors.primaryBlue).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insights,
                        color: isDark ? AppColors.primaryLight : AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Listing empty routes reduces dry-run miles and earns up to ₹30/km on routes otherwise driven empty.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Source & Destination
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _sourceController,
                        label: 'Origin City',
                        hintText: 'e.g. Mumbai',
                        prefixIcon: const Icon(Icons.circle_outlined, size: 18),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: _destinationController,
                        label: 'Destination City',
                        hintText: 'e.g. Ahmedabad',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Vehicle Registration Number
                CustomTextField(
                  controller: _vehicleNumberController,
                  label: 'Vehicle Number',
                  hintText: 'e.g. MH-04-AB-1234',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter vehicle number';
                    if (v.length < 5) return 'Enter valid registration number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Truck Type Dropdown
                Text(
                  'Truck Type',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTruckType,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  ),
                  dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                  items: _truckTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedTruckType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Capacity & Price
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _capacityController,
                        label: 'Capacity (Tons)',
                        hintText: 'e.g. 15',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: const Icon(Icons.scale_outlined),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Must be number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: _priceController,
                        label: 'Freight Cost (₹)',
                        hintText: 'e.g. 18000',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.currency_rupee),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Must be number';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date Selection
                Text(
                  'Available Return Date',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, color: theme.hintColor),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                        Icon(Icons.keyboard_arrow_down, color: theme.hintColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Submit Button
                CustomButton(
                  text: 'Publish Return Listing',
                  onPressed: _submitForm,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
