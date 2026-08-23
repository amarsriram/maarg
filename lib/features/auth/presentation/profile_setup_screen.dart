import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../domain/user_model.dart';
import '../data/auth_repository.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regionController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _handleFinish(UserRole role) async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final region = role == UserRole.provider ? _regionController.text.trim() : null;

      await ref.read(authRepositoryProvider).completeProfile(
        name: name,
        region: region,
      );

      // GoRouter redirect will automatically trigger once the Firestore
      // snapshot emits profileCompleted = true. No manual navigation needed.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final role = user.role;
    final isProvider = role == UserRole.provider;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF031B4E) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Complete Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Almost done!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isProvider 
                      ? 'Tell us about your logistics company.' 
                      : 'Tell us about yourself as a driver/owner.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : AppColors.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: 32),

                if (isProvider) ...[
                  CustomTextField(
                    controller: _nameController,
                    label: 'Provider Name',
                    hintText: 'Enter your business name',
                    prefixIcon: const Icon(Icons.business_outlined),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter provider name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _regionController,
                    label: 'Operating Region',
                    hintText: 'e.g. North India, Maharashtra, etc.',
                    prefixIcon: const Icon(Icons.map_outlined),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter operating region';
                      return null;
                    },
                  ),
                ] else ...[
                  CustomTextField(
                    controller: _nameController,
                    label: 'Driver Name',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person_outlined),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your name';
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 48),
                CustomButton(
                  text: 'Complete Setup',
                  onPressed: () => _handleFinish(role),
                  isLoading: _isSaving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
