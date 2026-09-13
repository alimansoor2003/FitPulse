import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/nutrition.dart';
import '../../../state/nutrition_providers.dart';
import '../../../state/settings_controller.dart';

/// Daily calories over the last week or month, with the averages worth
/// reading off them.
///
/// Food logs are never pruned, so this is a straight read over history - the
/// same rows the Today card shows, just over a wider window.
class NutritionTrendCard extends ConsumerWidget {
  const NutritionTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int range = ref.watch(nutritionRangeProvider);
    final NutritionTrend trend = ref.watch(nutritionTrendProvider).maybeWhen(
          data: (NutritionTrend t) => t,
          orElse: () => NutritionTrend.empty,
        );
    final MacroTargets targets =
        ref.watch(settingsProvider.select((AppSettings s) => s.macroTargets));

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RangeToggle(
            selected: range,
            onSelect: (int days) =>
                ref.read(nutritionRangeProvider.notifier).state = days,
          ),
          const SizedBox(height: 16),
          if (trend.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nothing logged in the last $range days. Meals you log are '
                'kept indefinitely, so this fills in as you go.',
                style: AppText.caption,
              ),
            )
          else ...<Widget>[
            _AverageBlock(trend: trend, targets: targets, range: range),
            const SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: _CalorieChart(trend: trend, targets: targets),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Container(
                  width: 14,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '${targets.calories} kcal target',
                  style: AppText.caption,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Wrap rather than Row: two fixed-width chips overflow to the right at a
    // large text scale, the same way the overload-step chips in Settings did.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final (int days, String label) in const <(int, String)>[
          (7, 'Last 7 days'),
          (30, 'Last 30 days'),
        ])
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

class _AverageBlock extends StatelessWidget {
  const _AverageBlock({
    required this.trend,
    required this.targets,
    required this.range,
  });

  final NutritionTrend trend;
  final MacroTargets targets;
  final int range;

  @override
  Widget build(BuildContext context) {
    final int delta = trend.average.calories - targets.calories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Both halves flex. A Spacer between them cannot shrink below zero,
        // so once the two labels alone are wider than the card - which they
        // are at the 1.15 text scale the app allows - the row overflowed.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      '${trend.average.calories}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.metric,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('kcal / day', style: AppText.caption),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  delta == 0
                      ? 'on target'
                      : '${delta > 0 ? '+' : '-'}${delta.abs()} vs target',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: sora(
                    11,
                    600,
                    color: delta > 0 ? AppColors.warning : AppColors.neonGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        // Say what the average is actually over. Dividing by the full window
        // would read as eating less rather than as days with no data.
        Text(
          'averaged over ${trend.daysLogged} '
          'day${trend.daysLogged == 1 ? '' : 's'} logged of $range',
          style: AppText.caption,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            _AverageMacro(
              label: 'Protein',
              grams: trend.average.proteinG,
              target: targets.proteinG,
              color: AppColors.neonCyan,
            ),
            _AverageMacro(
              label: 'Carbs',
              grams: trend.average.carbsG,
              target: targets.carbsG,
              color: AppColors.neonBlue,
            ),
            _AverageMacro(
              label: 'Fat',
              grams: trend.average.fatG,
              target: targets.fatG,
              color: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }
}

class _AverageMacro extends StatelessWidget {
  const _AverageMacro({
    required this.label,
    required this.grams,
    required this.target,
    required this.color,
  });

  final String label;
  final double grams;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${grams.round()} g', style: sora(15, 700)),
          Text('of ${target.round()}', style: AppText.caption),
        ],
      ),
    );
  }
}

class _CalorieChart extends StatelessWidget {
  const _CalorieChart({required this.trend, required this.targets});

  final NutritionTrend trend;
  final MacroTargets targets;

  @override
  Widget build(BuildContext context) {
    final List<DailyNutrition> days = trend.days;
    final double peak =
        trend.peakCalories.toDouble() > targets.calories.toDouble()
            ? trend.peakCalories.toDouble()
            : targets.calories.toDouble();

    // 30 bars cannot each carry a date, so label a handful of evenly spaced
    // days and leave the rest bare.
    final int labelStep = days.length <= 8 ? 1 : (days.length / 5).ceil();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: peak * 1.2,
        barTouchData: BarTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double value) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: <HorizontalLine>[
            HorizontalLine(
              y: targets.calories.toDouble(),
              color: AppColors.warning.withOpacity(0.55),
              strokeWidth: 1.5,
              dashArray: <int>[5, 4],
            ),
          ],
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                // Always label the newest day, then step backwards.
                final bool label =
                    (days.length - 1 - index) % labelStep == 0;
                if (!label) return const SizedBox.shrink();
                final DateTime d = days[index].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: sora(8, 400, color: AppColors.textTertiary),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List<BarChartGroupData>.generate(days.length, (int i) {
          final DailyNutrition d = days[i];
          return BarChartGroupData(
            x: i,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: d.calories.toDouble(),
                width: days.length > 12 ? 6 : 13,
                borderRadius: BorderRadius.circular(4),
                // An unlogged day is drawn as an empty slot rather than as a
                // zero-calorie day, so a gap in the record does not read as
                // a day of not eating.
                color: d.isLogged ? null : Colors.white.withOpacity(0.05),
                gradient: d.isLogged
                    ? const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: <Color>[
                          AppColors.neonBlue,
                          AppColors.neonCyan,
                        ],
                      )
                    : null,
                backDrawRodData: BackgroundBarChartRodData(
                  show: !d.isLogged,
                  toY: peak * 0.04,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
