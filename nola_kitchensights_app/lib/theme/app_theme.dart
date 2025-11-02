// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'ks_colors.dart';
import 'ks_text.dart';

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KSColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: KSColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );

    return base.copyWith(
      textTheme: KSText.textTheme,
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }
}
