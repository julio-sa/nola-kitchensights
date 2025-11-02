// lib/theme/ks_text.dart
import 'package:flutter/material.dart';
import 'ks_colors.dart';

class KSText {
  KSText._();

  // título de seção de dashboard
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: KSColors.textPrimary,
  );

  // texto padrão
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: KSColors.textSecondary,
  );

  // rótulo menor
  static const TextStyle label = TextStyle(
    fontSize: 12,
    color: KSColors.textSecondary,
  );

  /// isso que o `AppTheme` vai usar
  static TextTheme get textTheme => const TextTheme(
        titleMedium: title,
        bodyMedium: body,
        bodySmall: label,
      );
}
