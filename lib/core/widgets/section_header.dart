import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title, style: AppText.section),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: <Widget>[
                  Text(
                    actionLabel!,
                    style: sora(12, 500, color: AppColors.neonCyan),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.neonCyan,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small icon + value pill used inside the stats cards.
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent = AppColors.neonCyan,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: accent.withOpacity(0.22)),
          ),
          child: Icon(icon, size: 17, color: accent),
        ),
        const SizedBox(height: 9),
        Text(value, style: AppText.metricSmall),
        const SizedBox(height: 1),
        Text(label, style: AppText.caption),
      ],
    );
  }
}
