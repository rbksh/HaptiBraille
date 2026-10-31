import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/welcome/welcome_screen.dart';

class HaptiBrailleApp extends ConsumerWidget {
  const HaptiBrailleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read once: the welcome screen navigates to home itself when finished.
    final onboarded = ref.read(onboardedProvider);
    final theme = AppTheme.build();
    return MaterialApp(
      title: 'HaptiBraille',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: onboarded ? const HomeScreen() : const WelcomeScreen(),
    );
  }
}
