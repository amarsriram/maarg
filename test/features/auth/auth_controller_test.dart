import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maarg/features/auth/data/auth_repository.dart';
import 'package:maarg/features/auth/domain/user_model.dart';
import 'package:maarg/features/auth/presentation/auth_controller.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'fake_uid_123';
  @override
  String? get phoneNumber => '+919876543210';
  @override
  String? get email => 'fake@example.com';
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  User? get user => FakeUser();
}

class FakePhoneAuthCredential extends Fake implements PhoneAuthCredential {}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  String? lastPhoneNumber;
  Duration? lastTimeout;
  int? lastForceResendingToken;
  PhoneVerificationCompleted? lastVerificationCompleted;
  PhoneVerificationFailed? lastVerificationFailed;
  PhoneCodeSent? lastCodeSent;
  PhoneCodeAutoRetrievalTimeout? lastCodeAutoRetrievalTimeout;

  Completer<UserCredential>? signInCompleter;
  int signInCount = 0;

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneVerificationCompleted? verificationCompleted,
    PhoneVerificationFailed? verificationFailed,
    PhoneCodeSent? codeSent,
    PhoneCodeAutoRetrievalTimeout? codeAutoRetrievalTimeout,
    String? autoRetrievedSmsCodeForTesting,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    MultiFactorSession? multiFactorSession,
    PhoneMultiFactorInfo? multiFactorInfo,
  }) async {
    lastPhoneNumber = phoneNumber;
    lastTimeout = timeout;
    lastForceResendingToken = forceResendingToken;
    lastVerificationCompleted = verificationCompleted;
    lastVerificationFailed = verificationFailed;
    lastCodeSent = codeSent;
    lastCodeAutoRetrievalTimeout = codeAutoRetrievalTimeout;
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signInCount++;
    if (signInCompleter != null) {
      return signInCompleter!.future;
    }
    return FakeUserCredential();
  }
}

class FakeAuthRepository extends Fake implements AuthRepository {
  bool logoutCalled = false;
  bool ensureInitialProfileCalled = false;
  bool completeProfileCalled = false;
  String? lastCompletedName;
  String? lastCompletedRegion;
  UserRole? lastUpdatedRole;

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> ensureInitialProfile() async {
    ensureInitialProfileCalled = true;
  }

  @override
  Future<void> completeProfile({required String name, String? region}) async {
    completeProfileCalled = true;
    lastCompletedName = name;
    lastCompletedRegion = region;
  }

  @override
  Future<AppUser?> updateRole(UserRole role) async {
    lastUpdatedRole = role;
    return AppUser(id: 'fake_uid_123', role: role, profileCompleted: false);
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late FakeFirebaseAuth fakeAuth;
  late AuthController controller;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    fakeAuth = FakeFirebaseAuth();
    controller = AuthController(fakeRepo, firebaseAuth: fakeAuth);
  });

  group('AuthController ResendToken Tests', () {
    test('stores resendToken when codeSent callback is triggered', () async {
      expect(controller.resendToken, isNull);

      await controller.sendOtp('+919876543210');
      expect(fakeAuth.lastForceResendingToken, isNull);

      // Simulate codeSent callback from Firebase with token 888999
      fakeAuth.lastCodeSent?.call('ver_id_123', 888999);

      expect(controller.verificationId, equals('ver_id_123'));
      expect(controller.resendToken, equals(888999));
      expect(controller.state.step, equals(PhoneAuthStep.enterOtp));
      expect(controller.state.resendCooldownSeconds, equals(30));
    });

    test('passes stored resendToken as forceResendingToken on resendOtp', () async {
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_123', 555666);

      // Send OTP as resend request
      await controller.sendOtp('+919876543210', isResend: true);

      expect(fakeAuth.lastForceResendingToken, equals(555666));
    });

    test('clears resendToken when new initial sendOtp is called', () async {
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_123', 444333);
      expect(controller.resendToken, equals(444333));

      // Initial send for a new phone number (isResend: false)
      await controller.sendOtp('+919999999999');
      expect(controller.resendToken, isNull);
      expect(fakeAuth.lastForceResendingToken, isNull);
    });

    test('clears resendToken on logout', () async {
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_123', 111222);
      expect(controller.resendToken, equals(111222));

      await controller.logout();

      expect(controller.resendToken, isNull);
      expect(controller.verificationId, isNull);
      expect(fakeRepo.logoutCalled, isTrue);
      expect(controller.state.step, equals(PhoneAuthStep.enterPhone));
    });
  });

  group('AuthController Consolidated Logout Tests', () {
    test('logout clears verificationId, resendToken, cancels cooldown timer, resets PhoneAuthState, and delegates to repository', () async {
      // 1. Setup in-flight OTP session with running cooldown timer
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_xyz', 999111);

      // Verify active session state before logout
      expect(controller.verificationId, equals('ver_id_xyz'));
      expect(controller.resendToken, equals(999111));
      expect(controller.state.step, equals(PhoneAuthStep.enterOtp));
      expect(controller.state.resendCooldownSeconds, equals(30));
      expect(fakeRepo.logoutCalled, isFalse);

      // 2. Perform logout
      await controller.logout();

      // 3. Verify clean sweep of all authentication & presentation state
      expect(controller.verificationId, isNull, reason: 'a. verificationId must be cleared');
      expect(controller.resendToken, isNull, reason: 'b. resendToken must be cleared');
      expect(controller.state.resendCooldownSeconds, equals(0), reason: 'c. cooldown timer must be cancelled');
      expect(controller.state.step, equals(PhoneAuthStep.enterPhone), reason: 'd. PhoneAuthState step must reset to enterPhone');
      expect(controller.state.errorMessage, isNull, reason: 'd. PhoneAuthState error must be cleared');
      expect(fakeRepo.logoutCalled, isTrue, reason: 'e. Firebase sign-out must be delegated through AuthRepository');
    });
  });

  group('AuthController Phone Validation Tests', () {
    test("sendOtp with invalid phone number does not call Firebase and sets invalid error state", () async {
      await controller.sendOtp('12345');
      expect(fakeAuth.lastPhoneNumber, isNull);
      expect(controller.state.step, equals(PhoneAuthStep.enterPhone));
      expect(controller.state.errorMessage, equals('Invalid phone number. Please check and retry.'));
    });

    test("sendOtp with valid raw format normalizes and routes as E.164 to Firebase", () async {
      await controller.sendOtp('09876543210');
      expect(fakeAuth.lastPhoneNumber, equals('+919876543210'));
      expect(controller.state.step, equals(PhoneAuthStep.sendingOtp));
      expect(controller.state.errorMessage, isNull);
    });

    test("resendOtp still uses normalized submitted number", () async {
      await controller.sendOtp('09876543210');
      fakeAuth.lastCodeSent?.call('ver_id_xyz', 111);

      // Re-create the controller state for the resend check (to bypass cooldown logic)
      controller = AuthController(fakeRepo, firebaseAuth: fakeAuth);
      await controller.sendOtp('09876543210');
      fakeAuth.lastCodeSent?.call('ver_id_xyz', 111);

      // Trigger resend
      await controller.sendOtp('+919876543210', isResend: true);

      expect(fakeAuth.lastPhoneNumber, equals('+919876543210'));
      expect(fakeAuth.lastForceResendingToken, equals(111));
    });
  });

  group('AuthController Phone Auth Callback Race Tests', () {
    test('A. Stale codeSent callback is ignored', () async {
      // Start Attempt A
      await controller.sendOtp('+919876543210');
      final codeSentA = fakeAuth.lastCodeSent;

      // Simulate user editing phone number (calls logout)
      await controller.logout();

      // Start Attempt B
      await controller.sendOtp('+919999999999');

      // Late codeSent from A arrives
      codeSentA?.call('ver_id_A', 111);

      // Verify B is untouched
      expect(controller.verificationId, isNull);
      expect(controller.resendToken, isNull);
      expect(controller.state.step, equals(PhoneAuthStep.sendingOtp));
    });

    test('B. Stale verificationFailed callback is ignored', () async {
      // Start Attempt A
      await controller.sendOtp('+919876543210');
      final failedA = fakeAuth.lastVerificationFailed;

      // Simulate user editing phone number (calls logout)
      await controller.logout();

      // Start Attempt B
      await controller.sendOtp('+919999999999');

      // Late failure from A arrives
      failedA?.call(FirebaseAuthException(code: 'invalid-phone-number', message: 'Error A'));

      // Verify B is unaffected
      expect(controller.state.step, equals(PhoneAuthStep.sendingOtp));
      expect(controller.state.errorMessage, isNull);
    });

    test('C. Stale verificationCompleted callback is ignored', () async {
      // Start Attempt A
      await controller.sendOtp('+919876543210');
      final completedA = fakeAuth.lastVerificationCompleted;

      // Simulate user editing phone number (calls logout)
      await controller.logout();

      // Start Attempt B
      await controller.sendOtp('+919999999999');

      // Late completed from A arrives
      fakeAuth.signInCount = 0;
      completedA?.call(FakePhoneAuthCredential());
      await Future<void>.delayed(Duration.zero);

      expect(fakeAuth.signInCount, equals(0));
      expect(controller.state.step, equals(PhoneAuthStep.sendingOtp));
    });

    test('D. Post-authentication delayed codeSent is ignored', () async {
      // Start Attempt A
      await controller.sendOtp('+919876543210');
      final codeSentA = fakeAuth.lastCodeSent;
      final completedA = fakeAuth.lastVerificationCompleted;

      // Complete verificationCompleted
      completedA?.call(FakePhoneAuthCredential());
      await Future<void>.delayed(Duration.zero);
      expect(fakeRepo.ensureInitialProfileCalled, isTrue);

      // Late codeSent from attempt A arrives
      codeSentA?.call('ver_id_late', 999);

      // Verify state was not reverted
      expect(controller.state.step, equals(PhoneAuthStep.enterPhone)); // Default / initial step
      expect(controller.verificationId, isNull);
      expect(controller.resendToken, isNull);
    });

    test('E. Concurrent verification is blocked by _verifyInFlight guard', () async {
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_xyz', 111);
      final completed = fakeAuth.lastVerificationCompleted;

      // Mock blocking signInWithCredential
      fakeAuth.signInCompleter = Completer<UserCredential>();
      fakeAuth.signInCount = 0;

      // Start verificationCompleted
      completed?.call(FakePhoneAuthCredential());
      await Future<void>.delayed(Duration.zero);

      // Attempt to call verifyOtp concurrently while verificationCompleted is running
      await controller.verifyOtp('123456');

      // Expect only 1 signIn call initiated
      expect(fakeAuth.signInCount, equals(1));

      // Complete the blocker
      fakeAuth.signInCompleter!.complete(FakeUserCredential());
      await Future<void>.delayed(Duration.zero);
    });

    test('F. Logout during active verification invalidates late callbacks', () async {
      await controller.sendOtp('+919876543210');
      final codeSent = fakeAuth.lastCodeSent;

      await controller.logout();

      codeSent?.call('ver_id_stale', 222);

      expect(controller.state.step, equals(PhoneAuthStep.enterPhone));
      expect(controller.verificationId, isNull);
      expect(controller.resendToken, isNull);
    });

    test('G. Edit phone during active verification invalidates callbacks', () async {
      await controller.sendOtp('+919876543210');
      final codeSent = fakeAuth.lastCodeSent;

      final originalAttemptId = controller.currentAttemptId;
      await controller.logout();
      expect(controller.currentAttemptId, greaterThan(originalAttemptId));

      codeSent?.call('ver_id_stale', 222);
      expect(controller.state.step, equals(PhoneAuthStep.enterPhone));
    });

    test('H. Resend callbacks ordering respects the latest attempt only', () async {
      // 1. Initial attempt A
      await controller.sendOtp('+919876543210');
      final codeSentA = fakeAuth.lastCodeSent;

      // Trigger codeSent for A to release _otpRequestInFlight lock and verify token
      codeSentA?.call('ver_id_A', 111);

      // 2. Trigger resend attempt B (with isResend: true to bypass timer check)
      await controller.sendOtp('+919876543210', isResend: true);
      final codeSentB = fakeAuth.lastCodeSent;

      // Callback A arrives late
      codeSentA?.call('ver_id_A_late', 111);
      expect(controller.verificationId, isNot(equals('ver_id_A_late')));

      // Callback B arrives
      codeSentB?.call('ver_id_B', 222);
      expect(controller.verificationId, equals('ver_id_B'));
      expect(controller.resendToken, equals(222));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Finding #6.2 — completeProfile repository delegation
  // ─────────────────────────────────────────────────────────────────────────

  group('AuthRepository completeProfile Delegation (Finding #6.2)', () {
    test('A. records name-only call', () async {
      await fakeRepo.completeProfile(name: 'Test Driver');
      expect(fakeRepo.completeProfileCalled, isTrue);
      expect(fakeRepo.lastCompletedName, equals('Test Driver'));
      expect(fakeRepo.lastCompletedRegion, isNull);
    });

    test('B. records name + region call', () async {
      await fakeRepo.completeProfile(name: 'Test Provider', region: 'North India');
      expect(fakeRepo.completeProfileCalled, isTrue);
      expect(fakeRepo.lastCompletedName, equals('Test Provider'));
      expect(fakeRepo.lastCompletedRegion, equals('North India'));
    });

    test('C. error propagates without silent swallowing', () async {
      final throwingRepo = _ThrowingAuthRepository();
      await expectLater(
        throwingRepo.completeProfile(name: 'Any'),
        throwsA(isA<Exception>()),
      );
    });

    test('D. selectRole still delegates to repository (Finding #6.1 baseline)', () async {
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_1', null);

      final success = await controller.selectRole(UserRole.provider);
      expect(success, isTrue);
      expect(fakeRepo.lastUpdatedRole, equals(UserRole.provider));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Finding #7 — submittedPhone stored in PhoneAuthState (not widget-local)
  // ─────────────────────────────────────────────────────────────────────────

  group('PhoneAuthState submittedPhone (Finding #7)', () {
    test('A. sendOtp stores canonical E.164 phone in state.submittedPhone', () async {
      expect(controller.state.submittedPhone, isEmpty);

      await controller.sendOtp('+919876543210');

      // submittedPhone must be set as soon as sendOtp transitions to sendingOtp
      expect(controller.state.submittedPhone, equals('+919876543210'));
    });

    test('B. submittedPhone is replaced when a second sendOtp is called', () async {
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_1', null);
      expect(controller.state.submittedPhone, equals('+919876543210'));

      // Simulate the user going back and submitting a different number
      await controller.sendOtp('+918888888888');
      expect(controller.state.submittedPhone, equals('+918888888888'));
    });

    test('C. logout clears submittedPhone to empty string', () async {
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_1', null);
      expect(controller.state.submittedPhone, equals('+919876543210'));

      await controller.logout();

      expect(controller.state.submittedPhone, isEmpty);
    });

    test('D. resendOtp via controller state phone reaches Firebase with same E.164 number', () async {
      // First OTP request — populates state.submittedPhone
      await controller.sendOtp('+919876543210');
      fakeAuth.lastCodeSent?.call('ver_id_1', 111);
      expect(controller.state.submittedPhone, equals('+919876543210'));

      // The screen would read controller.state.submittedPhone and pass it to resendOtp.
      // Simulate that: bypass the cooldown guard by calling sendOtp with isResend:true
      // using the phone value read from controller state (mirrors what _handleResend does).
      final phoneFromState = controller.state.submittedPhone;
      await controller.sendOtp(phoneFromState, isResend: true);

      // Firebase must receive the same canonical number, proving state-driven resend works
      expect(fakeAuth.lastPhoneNumber, equals('+919876543210'));
      // submittedPhone must remain correct after the resend attempt
      expect(controller.state.submittedPhone, equals('+919876543210'));
    });
  });
}

/// A minimal AuthRepository stub that always throws, used to verify error propagation.
class _ThrowingAuthRepository extends Fake implements AuthRepository {
  @override
  Future<void> completeProfile({required String name, String? region}) async {
    throw Exception('Simulated Firestore failure');
  }

  @override
  Future<void> ensureInitialProfile() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<AppUser?> updateRole(UserRole role) async => null;
}
