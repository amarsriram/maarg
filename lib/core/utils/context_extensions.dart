import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafeNavigation on BuildContext {
  /// Safely navigate to a route using GoRouter, ensuring the context is still mounted.
  void safeGo(String route) {
    if (mounted) {
      go(route);
    }
  }

  /// Safely push a route using GoRouter, ensuring the context is still mounted.
  void safePush(String route, {Object? extra}) {
    if (mounted) {
      push(route, extra: extra);
    }
  }
}
