import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

/// Simple state provider to manage current theme mode (Light vs Dark).
final themeModeStateProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Root MaterialApp widget config for Maarg, wrapping the GoRouter structure.
class MaargApp extends ConsumerWidget {
  const MaargApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeStateProvider);

    return MaterialApp.router(
      title: 'Maarg Logistics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
