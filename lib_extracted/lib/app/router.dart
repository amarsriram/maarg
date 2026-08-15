import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/user_model.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/role_selection_screen.dart';
import '../features/auth/presentation/profile_setup_screen.dart';
import '../features/load_provider/presentation/load_provider_dashboard.dart';
import '../features/truck_owner/presentation/truck_owner_dashboard.dart';
import '../features/find_truck/domain/truck_model.dart';
import '../features/find_truck/presentation/truck_detail_screen.dart';

// Splash Screen — shown while auth stream is loading
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen<AsyncValue<AppUser?>>(
    authStateProvider,
    (_, __) => refreshNotifier.value++,
  );
  
  ref.onDispose(() {
    refreshNotifier.dispose();
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final currentUri = state.uri.toString();

      // ── STEP 1: No Firebase user → auth screen ──
      if (FirebaseAuth.instance.currentUser == null) {
        if (currentUri == '/auth') return null;
        return '/auth';
      }

      // ── STEP 2: Waiting for Firestore user doc ──
      final authState = ref.read(authStateProvider);

      if (authState.isLoading || authState.hasError) {
        return currentUri == '/splash' ? null : '/splash';
      }

      final user = authState.value;

      // ── STEP 3: User doc missing ──
      if (user == null) {
        return currentUri == '/splash' ? null : '/splash';
      }

      debugPrint('ROUTER LOCATION: ${state.matchedLocation}');
      debugPrint('ROUTER USER ROLE: ${user.role}');
      debugPrint('PROFILE COMPLETED: ${user.profileCompleted}');

      // ── STEP 4: EXISTING USERS ──
      final hasName = (user.name?.trim().isNotEmpty ?? false);
      final isAuthOrOnboarding =
          currentUri == '/auth' ||
          currentUri == '/role-selection' ||
          currentUri == '/profile-setup' ||
          currentUri == '/splash';

      if (user.role == UserRole.provider) {
        if (hasName || user.profileCompleted == true) {
          if (isAuthOrOnboarding) {
            debugPrint('REDIRECTING TO: /provider-dashboard');
            return '/provider-dashboard';
          }
          return null;
        }
        return currentUri == '/profile-setup' ? null : '/profile-setup';
      }

      if (user.role == UserRole.truckOwner) {
        if (hasName || user.profileCompleted == true) {
          if (isAuthOrOnboarding) {
            debugPrint('REDIRECTING TO: /truck-owner-dashboard');
            return '/truck-owner-dashboard';
          }
          return null;
        }
        return currentUri == '/profile-setup' ? null : '/profile-setup';
      }

      // ── STEP 5: NEW USERS ONLY ──
      if (user.role == UserRole.none) {
        debugPrint('REDIRECTING TO: /role-selection');
        return currentUri == '/role-selection' ? null : '/role-selection';
      }

      // ── STEP 7: Stay on current route ──
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/provider-dashboard',
        builder: (context, state) => const LoadProviderDashboard(),
      ),
      GoRoute(
        path: '/truck-owner-dashboard',
        builder: (context, state) => const TruckOwnerDashboard(),
      ),
      GoRoute(
        path: '/truck/:id',
        builder: (context, state) {
          final truck = state.extra as TruckRoute?;
          final truckId = state.pathParameters['id'] ?? '';
          return TruckDetailScreen(truckId: truckId, preloadedRoute: truck);
        },
      ),
    ],
  );
});
