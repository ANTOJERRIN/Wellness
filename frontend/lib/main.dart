import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/chat/presentation/dashboard_screen.dart';
import 'features/landing/presentation/landing_screen.dart';

void main() {
  runApp(const ProviderScope(child: MedGenieApp()));
}

class MedGenieApp extends ConsumerWidget {
  const MedGenieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Med Genie — AI Health Assistant',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: authState.isAuthenticated
          ? const DashboardScreen()
          : const LandingScreen(),
    );
  }
}
