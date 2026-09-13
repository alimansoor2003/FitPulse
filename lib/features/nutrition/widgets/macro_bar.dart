import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// One macro's progress toward its daily target.
///
/// Deliberately a plain [DecoratedBox] pair rather than a painter or a
/// [BackdropFilter]: three of these sit inside a card in the Home list, so
/// they have to be free to scroll past.
class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.label,
    required this.grams,
    required this.targetGrams,
    required this.color,
  });

  final String label;
  final double grams;
  final double targetGrams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double progress =
        targetGrams <= 0 ? 0 : (grams / targetGrams).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: sora(11, 600, color: AppColors.textSecondary),
                ),
              ),
              Text(
                '${grams.round()} / ${targetGrams.round()} g',
                style: sora(11, 500, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: <Widget>[
                Container(height: 6, color: AppColors.glassFillStrong),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double value, Widget? _) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: Container(height: 6, color: color),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
