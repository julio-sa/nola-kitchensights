// lib/widgets/common/dashboard_badge.dart
import 'package:flutter/material.dart';
import 'package:nola_kitchensights_app/theme/ks_colors.dart';

enum DashboardBadgeTone { info, success, danger, insight }

class DashboardBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final DashboardBadgeTone tone;

  const DashboardBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = DashboardBadgeTone.info,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (tone) {
      case DashboardBadgeTone.info:
        bg = KSColors.infoBg;
        fg = KSColors.infoFg;
      case DashboardBadgeTone.success:
        bg = KSColors.successBg;
        fg = KSColors.successFg;
      case DashboardBadgeTone.danger:
        bg = KSColors.dangerBg;
        fg = KSColors.dangerFg;
      case DashboardBadgeTone.insight:
        bg = KSColors.insightBg;
        fg = KSColors.insightFg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
