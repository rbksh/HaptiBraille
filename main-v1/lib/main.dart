import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/haptic_test/haptic_test_screen.dart';

void main() {
  runApp(const ProviderScope(child: VibeReadApp()));
}

class VibeReadApp extends StatelessWidget {
  const VibeReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    // High-contrast dark theme for low-vision users.
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.highContrastDark(),
      scaffoldBackgroundColor: Colors.black,
    );
    return MaterialApp(
      title: 'VibeRead',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const HapticTestScreen(),
    );
  }
}
