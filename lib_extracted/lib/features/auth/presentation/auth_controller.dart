import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

/// AuthController manages UI loading and error states during authentication actions.
class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AsyncValue.data(null)) {
    // If there is an active current user (e.g. cached), load it
    final current = _authRepository.currentUser;
    if (current != null) {
      state = AsyncValue.data(current);
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.login(email, password);
      state = AsyncValue.data(user);
      return user != null;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.register(email, password);
      state = AsyncValue.data(user);
      return user != null;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> selectRole(UserRole role) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.updateRole(role);
      state = AsyncValue.data(user);
      return user != null;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.logout();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Controller Provider
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});
