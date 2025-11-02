// lib/theme/ks_colors.dart
import 'package:flutter/material.dart';

/// Paleta base do KitchenSights
class KSColors {
  KSColors._();

  // cores principais
  static const Color primary = Color(0xFF006494);
  static const Color background = Color(0xFFF4F5F7);

  // texto
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF52616B);

  // estados / badges
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color successFg = Color(0xFF2E7D32);

  static const Color dangerBg = Color(0xFFFFEBEE);
  static const Color dangerFg = Color(0xFFC62828);

  static const Color infoBg = Color(0xFFE3F2FD);
  static const Color infoFg = Color(0xFF1565C0);

  // “insight”/alerta suave
  static const Color insightBg = Color(0xFFFFF3E0);
  static const Color insightFg = Color(0xFFE65100);
}
