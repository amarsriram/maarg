import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/utils/phone_number_utils.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return;

    final normalized = PhoneNumberUtils.normalizeIndianMobileNumber(raw);
    if (PhoneNumberUtils.isValidIndianMobileNumber(normalized)) {
      final e164 = PhoneNumberUtils.toE164(normalized);
      await ref.read(authControllerProvider.notifier).sendOtp(e164);
      if (mounted) _otpFocus.requestFocus();
    } else {
      await ref.read(authControllerProvider.notifier).sendOtp(raw);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;
    await ref.read(authControllerProvider.notifier).verifyOtp(otp);
  }

  Future<void> _handleResend() async {
    final submittedPhone = ref.read(authControllerProvider).submittedPhone;
    _otpController.clear();
    await ref.read(authControllerProvider.notifier).resendOtp(submittedPhone);
  }

  void _handleEditPhone() {
    ref.read(authControllerProvider.notifier).logout();
    _otpController.clear();
    _phoneFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final step = authState.step;

    final isPhoneStep = step == PhoneAuthStep.enterPhone || step == PhoneAuthStep.sendingOtp;
    final isOtpStep = step == PhoneAuthStep.enterOtp || step == PhoneAuthStep.verifyingOtp;
    final isInitializing = step == PhoneAuthStep.initializingProfile;
    final isFailed = step == PhoneAuthStep.profileCreationFailed;

    return Scaffold(
      backgroundColor: const Color(0xFF031B4E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _buildLogo(),
              const SizedBox(height: 48),
              _buildHeadline(authState),
              const SizedBox(height: 36),
              if (isPhoneStep) _buildPhoneField(authState),
              if (isOtpStep) _buildOtpField(authState),
              if (isInitializing) _buildInitializingIndicator(),
              if (isFailed) _buildRetryCard(authState),
              const SizedBox(height: 32),
              if (isPhoneStep)
                CustomButton(
                  text: 'Send OTP',
                  onPressed: step == PhoneAuthStep.enterPhone ? _handleSendOtp : null,
                  isLoading: step == PhoneAuthStep.sendingOtp,
                ),
              if (isOtpStep)
                CustomButton(
                  text: 'Verify OTP',
                  onPressed: step == PhoneAuthStep.enterOtp ? _handleVerifyOtp : null,
                  isLoading: step == PhoneAuthStep.verifyingOtp,
                ),
              if (isFailed)
                CustomButton(
                  text: 'Retry',
                  onPressed: () => ref.read(authControllerProvider.notifier).retryProfileCreation(),
                ),
              if (isOtpStep) ...[
                const SizedBox(height: 24),
                _buildResendRow(authState),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Image.asset(
          'assets/images/maarg_logo.png',
          width: 48,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.arrow_outward_rounded,
            color: AppColors.primaryBlue,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline(PhoneAuthState authState) {
    final step = authState.step;
    String title;
    String subtitle;
    switch (step) {
      case PhoneAuthStep.enterPhone:
      case PhoneAuthStep.sendingOtp:
        title = 'Welcome to Maarg';
        subtitle = 'Enter your mobile number to get started.';
        break;
      case PhoneAuthStep.enterOtp:
      case PhoneAuthStep.verifyingOtp:
        title = 'Verify your number';
        subtitle = 'Enter the 6-digit OTP sent to ${authState.submittedPhone}';
        break;
      case PhoneAuthStep.initializingProfile:
        title = 'Setting up your account';
        subtitle = 'Almost there — just a moment.';
        break;
      case PhoneAuthStep.profileCreationFailed:
        title = 'Connection issue';
        subtitle = 'Your phone was verified. We could not reach the server to complete setup.';
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 15, height: 1.5)),
      ],
    );
  }

  Widget _buildPhoneField(PhoneAuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Mobile Number'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: authState.errorMessage != null ? AppColors.error : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: const Text('+91', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                   inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                  ],
                  maxLength: 20,
                  style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), letterSpacing: 1),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _handleSendOtp(),
                ),
              ),
            ],
          ),
        ),
        if (authState.errorMessage != null) ...[
          const SizedBox(height: 8),
          _errorText(authState.errorMessage!),
        ],
      ],
    );
  }

  Widget _buildOtpField(PhoneAuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('One-Time Password'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1628),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: authState.errorMessage != null ? AppColors.error : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: TextField(
            controller: _otpController,
            focusNode: _otpFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 22, letterSpacing: 8),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              counterText: '',
            ),
            onSubmitted: (_) => _handleVerifyOtp(),
            onChanged: (val) {
              if (val.length == 6) _handleVerifyOtp();
            },
          ),
        ),
        if (authState.errorMessage != null) ...[
          const SizedBox(height: 8),
          _errorText(authState.errorMessage!),
        ],
      ],
    );
  }

  Widget _buildInitializingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Setting up your Maarg account…',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryCard(PhoneAuthState authState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(authState.errorMessage ?? 'Profile creation failed.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildResendRow(PhoneAuthState authState) {
    final cooldown = authState.resendCooldownSeconds;
    final canResend = cooldown == 0 && authState.step == PhoneAuthStep.enterOtp;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _handleEditPhone,
          child: Text('Edit number', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
        ),
        TextButton(
          onPressed: canResend ? _handleResend : null,
          child: Text(
            cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend OTP',
            style: TextStyle(
              color: canResend ? AppColors.primaryBlue : Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8));
  }

  Widget _errorText(String message) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12))),
      ],
    );
  }
}
