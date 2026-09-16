import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../domain/hydration.dart';
import '../../../state/hydration_providers.dart';
import '../../../state/settings_controller.dart';
import '../custom_water_sheet.dart';

/// Today's water intake with one-tap logging, on the Today screen.
///
/// Mirrors the nutrition card's rhythm - ring on the left, figures on the
/// right, actions underneath - so the two read as a pair.
class HydrationCard extends ConsumerWidget {
  const HydrationCard({super.key});

  Future<void> _add(WidgetRef ref, int ml, {required int goalMl}) async {
    final HydrationToday before = ref.read(todayHydrationProvider);
    await ref.read(hydrationRepositoryProvider).logDrink(ml);

    // A heavier tap for the drink that crosses the goal, so reaching it is
    // felt as well as seen.
    final bool crossedGoal =
        before.totalMl < goalMl && before.totalMl + ml >= goalMl;
    if (crossedGoal) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _addCustom(
    BuildContext context,
    WidgetRef ref, {
    required int goalMl,
  }) async {
    final int? ml = await showCustomWaterSheet(context);
    if (ml == null) return;
    await _add(ref, ml, goalMl: goalMl);
  }

  Future<void> _undo(WidgetRef ref, HydrationToday today) async {
    final int? id = today.lastDrinkId;
    if (id == null) return;
    await ref.read(hydrationRepositoryProvider).deleteWaterLog(id);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HydrationToday today = ref.watch(todayHydrationProvider);
    final int goalMl =
        ref.watch(settingsProvider.select((AppSettings s) => s.waterGoalMl));

    final double progress = today.progressToward(goalMl);
    final int remaining = goalMl - today.totalMl;
    final bool reached = remaining <= 0;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ProgressRing(
                value: progress,
                size: 86,
                stroke: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.water_drop_rounded,
                      size: 18,
                      color: reached
                          ? AppColors.neonGreen
                          : AppColors.neonCyan,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(progress * 100).round()}%',
                      style: sora(14, 700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Scales down rather than overflowing if a big total
                    // meets a large system text scale.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatWaterMl(today.totalMl),
                        style: AppText.metric,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${formatWaterMl(goalMl)} daily goal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        if (reached) ...<Widget>[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.neonGreen,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            reached
                                ? 'Goal reached'
                                : '${formatWaterMl(remaining)} to go',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sora(
                              12,
                              600,
                              color: reached
                                  ? AppColors.neonGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              for (final WaterPreset preset in kWaterPresets) ...<Widget>[
                Expanded(
                  child: _QuickAddButton(
                    icon: preset.amountMl >= 500
                        ? Icons.local_drink_rounded
                        : Icons.water_drop_outlined,
                    amount: '+${formatWaterMl(preset.amountMl)}',
                    caption: preset.label,
                    onTap: () => _add(ref, preset.amountMl, goalMl: goalMl),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _QuickAddButton(
                  icon: Icons.tune_rounded,
                  amount: 'Custom',
                  caption: 'Any amount',
                  onTap: () => _addCustom(context, ref, goalMl: goalMl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  today.drinkCount == 0
                      ? 'Nothing logged yet today'
                      : '${today.drinkCount} '
                          'drink${today.drinkCount == 1 ? '' : 's'} today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
              if (today.canUndo)
                _UndoButton(
                  label: 'Undo ${formatWaterMl(today.lastDrinkMl ?? 0)}',
                  onTap: () => _undo(ref, today),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.icon,
    required this.amount,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String amount;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.neonCyan.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neonCyan.withOpacity(0.22)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.neonCyan),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(amount, maxLines: 1, style: sora(13, 700)),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(caption, maxLines: 1, style: AppText.caption),
            ),
          ],
        ),
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.undo_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: sora(11, 600, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
