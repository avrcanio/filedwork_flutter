import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_update/app_update_listener.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';

class FieldworkApp extends ConsumerWidget {
  const FieldworkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final authStatus =
        ref.watch(authControllerProvider.select((s) => s.status));

    return MaterialApp(
      title: 'Dalekopro Teren',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) =>
          AppUpdateListener(child: child ?? const SizedBox.shrink()),
      home: switch (authStatus) {
        AuthStatus.unknown => const _SplashScreen(),
        AuthStatus.authenticated => const HomeShell(),
        AuthStatus.unauthenticated => const LoginScreen(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
