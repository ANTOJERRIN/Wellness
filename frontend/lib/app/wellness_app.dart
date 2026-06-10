import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/chat/presentation/dashboard_screen.dart';
import '../features/landing/presentation/landing_screen.dart';
import '../core/constants/app_text.dart';
import 'theme.dart';
import 'router.dart';

class WellnessApp extends ConsumerWidget {
  const WellnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppText.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      onGenerateRoute: AppRouter.generateRoute,
      home: authState.isAuthenticated
          ? const DashboardScreen()
          : const LandingScreen(),
    );
  }
}
