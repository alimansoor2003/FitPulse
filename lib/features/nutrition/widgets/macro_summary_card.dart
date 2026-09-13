import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/neon_button.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/db/app_database.dart';
import '../../../domain/nutrition.dart';
import '../../../state/nutrition_providers.dart';
import '../../../state/settings_controller.dart';
import '../food_logger_sheet.dart';
import 'macro_bar.dart';

/// Today's calories and macros, plus the entry point into the food logger.
class MacroSummaryCard extends ConsumerWidget {
  const MacroSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DailyMacros macros = ref.watch(todayMacrosProvider);
    final MacroTargets targets =
        ref.watch(settingsProvider.select((AppSettings s) => s.macroTargets));
    final List<FoodLog> logs = ref.watch(todayFoodLogsProvider).maybeWhen(
          data: (List<FoodLog> rows) => rows,
          orElse: () => const <FoodLog>[],
        );

    final double calorieProgress = targets.calories <= 0
        ? 0
        : (macros.calories / targets.calories).clamp(0.0, 1.0);
    final int remaining = targets.calories - macros.calories;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ProgressRing(
                value: calorieProgress,
                size: 86,
                stroke: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('${macros.calories}', style: sora(18, 700)),
                    Text('kcal', style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MacroBar(
                      label: 'Protein',
                      grams: macros.proteinG,
                      targetGrams: targets.proteinG,
                      color: AppColors.neonCyan,
                    ),
                    MacroBar(
                      label: 'Carbs',
                      grams: macros.carbsG,
                      targetGrams: targets.carbsG,
                      color: AppColors.neonBlue,
                    ),
                    MacroBar(
                      label: 'Fat',
                      grams: macros.fatG,
                      targetGrams: targets.fatG,
                      color: AppColors.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            remaining >= 0
                ? '$remaining kcal left of ${targets.calories} today'
                : '${-remaining} kcal over your ${targets.calories} target',
            style: AppText.caption,
          ),
          const SizedBox(height: 14),
          NeonButton(
            label: 'LOG FOOD',
            height: 48,
            icon: Icons.restaurant_rounded,
            onPressed: () => showFoodLoggerSheet(context),
          ),
          if (logs.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${logs.length} item${logs.length == 1 ? '' : 's'} today',
                    style: sora(11, 600, color: AppColors.textSecondary),
                  ),
                ),
                Text('swipe to remove', style: AppText.caption),
              ],
            ),
            const SizedBox(height: 8),
            ...logs.map(
              (FoodLog log) => _LoggedItemRow(
                key: ValueKey<int>(log.id),
                log: log,
                onDelete: () async {
                  await ref
                      .read(nutritionRepositoryProvider)
                      .deleteFoodLog(log.id);
                  HapticFeedback.mediumImpact();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoggedItemRow extends StatelessWidget {
  const _LoggedItemRow({super.key, required this.log, required this.onDelete});

  final FoodLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey<int>(log.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 14),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          size: 18,
          color: AppColors.danger,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    log.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sora(12, 600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${log.mealType} - P ${log.proteinG.round()} / '
                    'C ${log.carbsG.round()} / F ${log.fatG.round()}',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${log.calories}',
              style: sora(13, 700, color: AppColors.neonCyan),
            ),
            const SizedBox(width: 2),
            Text('kcal', style: AppText.caption),
          ],
        ),
      ),
    );
  }
}
