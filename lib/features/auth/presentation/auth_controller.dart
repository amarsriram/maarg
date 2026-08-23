import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import '../../../core/utils/phone_number_utils.dart';

// ─────────────────────────────────────────────────────────
// Auth State
// ─────────────────────────────────────────────────────────

/// Represents the transient Phone Auth UI step.
/// Persistent user/profile state is owned by authStateProvider.
enum PhoneAuthStep {
  enterPhone,
  sendingOtp,
  enterOtp,
  verifyingOtp,
  initializingProfile,
  profileCreationFailed,
}

class PhoneAuthState {
  final PhoneAuthStep step;
  final String? errorMessage;
  final int resendCooldownSeconds;
  /// The canonical E.164 phone number submitted for the current OTP flow.
  /// Stored in controller state so it survives widget rebuilds (Finding #7).
  final String submittedPhone;

  const PhoneAuthState({
    this.step = PhoneAuthStep.enterPhone,
    this.errorMessage,
    this.resendCooldownSeconds = 0,
    this.submittedPhone = '',
  });

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    String? errorMessage,
    bool clearError = false,
    int? resendCooldownSeconds,
    String? submittedPhone,
  }) {
    return PhoneAuthState(
      step: step ?? this.step,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resendCooldownSeconds: resendCooldownSeconds ?? this.resendCooldownSeconds,
      submittedPhone: submittedPhone ?? this.submittedPhone,
    );
  }
}

// ─────────────────────────────────────────────────────────
// AuthController
// ─────────────────────────────────────────────────────────

class AuthController extends StateNotifier<PhoneAuthState> {
  final AuthRepository _authRepository;
  final FirebaseAuth _firebaseAuth;

  String? _verificationId;
  int? _resendToken;
  bool _otpRequestInFlight = false;
  bool _verifyInFlight = false;
  Timer? _cooldownTimer;
  int _currentAttemptId = 0;

  AuthController(this._authRepository, {FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(const PhoneAuthState());

  @visibleForTesting
  int? get resendToken => _resendToken;

  @visibleForTesting
  String? get verificationId => _verificationId;

  @visibleForTesting
  int get currentAttemptId => _currentAttemptId;

  // ──────────────────────────────────
  // Public API
  // ──────────────────────────────────

  Future<void> sendOtp(String phoneNumber, {bool isResend = false}) async {
    if (_otpRequestInFlight) {
      debugPrint('[AUTH] OTP_REQUEST_BLOCKED — already in flight');
      return;
    }

    final normalized = PhoneNumberUtils.normalizeIndianMobileNumber(phoneNumber);
    if (!PhoneNumberUtils.isValidIndianMobileNumber(normalized)) {
      debugPrint('[AUTH] OTP_REQUEST_FAILED — invalid phone number: $phoneNumber');
      state = state.copyWith(
        step: PhoneAuthStep.enterPhone,
        errorMessage: 'Invalid phone number. Please check and retry.',
      );
      return;
    }
    final formatted = PhoneNumberUtils.toE164(normalized);

    final attemptId = ++_currentAttemptId;

    _otpRequestInFlight = true;
    _cooldownTimer?.cancel();
    _verificationId = null;
    if (!isResend) {
      _resendToken = null;
    }

    state = state.copyWith(
      step: PhoneAuthStep.sendingOtp,
      clearError: true,
      submittedPhone: formatted,
    );
    debugPrint('[AUTH] OTP_REQUEST_STARTED');

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: formatted,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (attemptId != _currentAttemptId) {
          debugPrint('[AUTH] Callback verificationCompleted ignored — stale attempt');
          return;
        }
        debugPrint('[AUTH] OTP_AUTO_VERIFIED');
        _otpRequestInFlight = false;
        await _verifyWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (attemptId != _currentAttemptId) {
          debugPrint('[AUTH] Callback verificationFailed ignored — stale attempt');
          return;
        }
        _otpRequestInFlight = false;
        debugPrint('[AUTH] OTP_SEND_FAILED: ${e.code}');
        state = state.copyWith(
          step: PhoneAuthStep.enterPhone,
          errorMessage: _friendlyAuthError(e),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        if (attemptId != _currentAttemptId) {
          debugPrint('[AUTH] Callback codeSent ignored — stale attempt');
          return;
        }
        _otpRequestInFlight = false;
        _verificationId = verificationId;
        if (resendToken != null) {
          _resendToken = resendToken;
        }
        debugPrint('[AUTH] OTP_SENT');
        state = state.copyWith(
          step: PhoneAuthStep.enterOtp,
          clearError: true,
          resendCooldownSeconds: 30,
        );
        _startCooldown();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (attemptId != _currentAttemptId) {
          debugPrint('[AUTH] Callback codeAutoRetrievalTimeout ignored — stale attempt');
          return;
        }
        _verificationId = verificationId;
        debugPrint('[AUTH] OTP_AUTO_RETRIEVAL_TIMEOUT');
      },
    );
  }

  Future<void> verifyOtp(String otp) async {
    final vid = _verificationId;
    if (vid == null) {
      state = state.copyWith(
        errorMessage: 'Session expired. Please request a new OTP.',
      );
      return;
    }
    if (_verifyInFlight) {
      debugPrint('[AUTH] OTP_VERIFY_BLOCKED — already in flight');
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: vid,
      smsCode: otp,
    );
    await _verifyWithCredential(credential);
  }

  Future<void> resendOtp(String phoneNumber) async {
    if (state.resendCooldownSeconds > 0) return;
    _verificationId = null;
    await sendOtp(phoneNumber, isResend: true);
  }

  Future<void> retryProfileCreation() async {
    if (state.step != PhoneAuthStep.profileCreationFailed) return;
    await _runEnsureInitialProfile();
  }

  Future<bool> selectRole(UserRole role) async {
    try {
      await _authRepository.updateRole(role);
      return true;
    } catch (e, stack) {
      debugPrint('[AUTH] ROLE_UPDATE_FAILED: $e\n$stack');
      return false;
    }
  }

  Future<void> logout() async {
    _cooldownTimer?.cancel();
    _verificationId = null;
    _resendToken = null;
    _otpRequestInFlight = false;
    _verifyInFlight = false;
    _currentAttemptId++; // Invalidate any pending callbacks
    await _authRepository.logout();
    debugPrint('[AUTH] LOGOUT');
    state = const PhoneAuthState();
  }

  // ──────────────────────────────────
  // Private helpers
  // ──────────────────────────────────

  Future<void> _verifyWithCredential(PhoneAuthCredential credential) async {
    if (_verifyInFlight) {
      debugPrint('[AUTH] OTP_VERIFY_BLOCKED — verification already in flight');
      return;
    }
    _verifyInFlight = true;
    state = state.copyWith(step: PhoneAuthStep.verifyingOtp, clearError: true);
    debugPrint('[AUTH] OTP_VERIFICATION_STARTED');
    try {
      await _firebaseAuth.signInWithCredential(credential);
      debugPrint('[AUTH] OTP_VERIFICATION_SUCCESS');
      await _runEnsureInitialProfile();
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] OTP_VERIFICATION_FAILED: ${e.code}');
      state = state.copyWith(
        step: PhoneAuthStep.enterOtp,
        errorMessage: _friendlyAuthError(e),
      );
    } catch (e) {
      debugPrint('[AUTH] OTP_VERIFICATION_ERROR: $e');
      state = state.copyWith(
        step: PhoneAuthStep.enterOtp,
        errorMessage: 'Verification failed. Please try again.',
      );
    } finally {
      _verifyInFlight = false;
    }
  }

  Future<void> _runEnsureInitialProfile() async {
    state = state.copyWith(
      step: PhoneAuthStep.initializingProfile,
      clearError: true,
    );
    debugPrint('[AUTH] PROFILE_LOOKUP_STARTED');
    try {
      await _authRepository.ensureInitialProfile();
      debugPrint('[AUTH] INITIAL_PROFILE_CREATED');
      _verificationId = null;
      _resendToken = null;
      _currentAttemptId++; // Invalidate any delayed/stale callbacks after successful auth
      // GoRouter reacts to the Firestore stream update — no manual navigation.
      state = const PhoneAuthState();
    } catch (e) {
      debugPrint('[AUTH] PROFILE_CREATION_FAILED: $e');
      // Preserve Firebase Auth session. Expose explicit retry.
      state = state.copyWith(
        step: PhoneAuthStep.profileCreationFailed,
        errorMessage:
            'Could not create your profile. Please check your connection and retry.',
      );
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.resendCooldownSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(resendCooldownSeconds: 0);
      } else {
        state = state.copyWith(resendCooldownSeconds: remaining);
      }
    });
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number. Please check and retry.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'network-request-failed':
        return 'No internet connection. Please reconnect and retry.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────

final authControllerProvider =
    StateNotifierProvider<AuthController, PhoneAuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

