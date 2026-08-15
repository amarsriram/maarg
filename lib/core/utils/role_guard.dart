import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/user_model.dart';

/// A middleware wrapper widget that ensures the user has the required role
/// to view the protected child screen. If the role does not match, it shows
/// an access denied message and a button to return home.
class RoleGuard extends ConsumerWidget {
  final UserRole requiredRole;
  final Widget child;

  const RoleGuard({
    super.key,
    required this.requiredRole,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);

    return userState.when(
      data: (user) {
        if (user == null) {
          // If unauthenticated, the router should catch this, but just in case:
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (user.role != requiredRole) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Access Restricted',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You do not have permission to view this page.\nRequired: ${requiredRole.displayName}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        // Role matches, allow access
        return child;
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, stack) => Scaffold(body: Center(child: Text('Error verifying role: $e'))),
    );
  }
}
