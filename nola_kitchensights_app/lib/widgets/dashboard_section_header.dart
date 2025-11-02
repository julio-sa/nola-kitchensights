// lib/widgets/dashboard_section_header.dart

import 'package:flutter/material.dart';

class DashboardBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const DashboardBadge({
    super.key,
    required this.label,
    this.background = const Color(0xFFE0F2F1),
    this.foreground = const Color(0xFF004D40),
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final DashboardBadge? badge;
  final Widget? trailing;

  const DashboardSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Row(
      crossAxisAlignment:
          subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 18,
          // aqui trocamos o withOpacity pra withValues pra não dar warning
          backgroundColor: primary.withValues(alpha: 0.08),
          child: Icon(
            icon,
            color: primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (badge != null) badge!,
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (theme.textTheme.bodySmall?.color ?? Colors.black)
                        .withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ]
      ],
    );
  }
}
