import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The "Last 7 days / Last 30 days" pill pair used by the trend cards.
class RangeToggle extends StatelessWidget {
  const RangeToggle({
    super.key,
    required this.selected,
    required this.onSelect,
    this.options = kDefaultRangeOptions,
  });

  static const List<(int, String)> kDefaultRangeOptions = <(int, String)>[
    (7, 'Last 7 days'),
    (30, 'Last 30 days'),
  ];

  final int selected;
  final ValueChanged<int> onSelect;
  final List<(int, String)> options;

  @override
  Widget build(BuildContext context) {
    // Wrap rather than Row: fixed-width chips in a Row overflow to the right
    // at a large text scale, the same way the overload-step chips did.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final (int days, String label) in options)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(days);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: days == selected ? AppColors.accentGradient : null,
                color:
                    days == selected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: days == selected
                      ? Colors.transparent
                      : AppColors.glassBorder,
                ),
              ),
              child: Text(
                label,
                style: sora(
                  11,
                  600,
                  color: days == selected
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
