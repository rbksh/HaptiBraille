import 'package:flutter/material.dart';

/// Colour tokens. High-contrast dark: every text colour is ≥ 7:1 on [bg]
/// except [textMuted] (≥ 4.5:1), which is only used for secondary labels.
abstract final class AppColors {
  static const bg = Color(0xFF0B0D10);
  static const surface = Color(0xFF14171C);
  static const surfaceHigh = Color(0xFF1E232A);
  static const outline = Color(0xFF3A414C);

  static const text = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC5CCD6);
  static const textMuted = Color(0xFF8A94A3);

  /// Interactive accent (buttons, raised dots). Never used for chart data.
  static const accent = Color(0xFFFFC940);
  static const onAccent = Color(0xFF111111);

  /// Single-series chart mark, validated for the dark chart surface.
  static const chart = Color(0xFF1FA2B5);

  static const success = Color(0xFF4ADE80);
  static const error = Color(0xFFFF7A7A);

  // Card tints for the home screen tiles.
  static const read = Color(0xFFFFC940);
  static const talk = Color(0xFF7DD3FC);
  static const train = Color(0xFFC4B5FD);
  static const progress = Color(0xFF86EFAC);
}

abstract final class AppTheme {
  static const fontFamily = 'AtkinsonHyperlegible';

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.talk,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.outline,
      error: AppColors.error,
      onError: AppColors.onAccent,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 46, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -0.5),
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.1),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.25),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
      bodyLarge: TextStyle(fontSize: 19, height: 1.45),
      bodyMedium: TextStyle(fontSize: 17, height: 1.45),
      bodySmall: TextStyle(fontSize: 15, height: 1.4),
      labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      labelMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.4),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
        fontFamily: fontFamily,
      ),
    );

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 60),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.outline, width: 1.5),
          shape: rounded,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(18),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.accent, width: 2.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 6,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.outline,
        thumbColor: AppColors.accent,
        valueIndicatorColor: AppColors.accent,
        valueIndicatorTextStyle: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w700),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.onAccent : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surfaceHigh,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(fontFamily: fontFamily, fontSize: 17, color: AppColors.text),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1),
    );
  }
}
