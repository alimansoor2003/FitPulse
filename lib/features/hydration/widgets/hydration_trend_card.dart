import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/daily_target_bar_chart.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/range_toggle.dart';
import '../../../domain/hydration.dart';
import '../../../state/hydration_providers.dart';
import '../../../state/settings_controller.dart';

/// Daily water over the last week or month, on the Progress screen.
class HydrationTrendCard extends ConsumerWidget {
  const HydrationTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int range = ref.watch(hydrationRangeProvider);
    final HydrationTrend trend = ref.watch(hydrationTrendProvider).maybeWhen(
          data: (HydrationTrend t) => t,
          orElse: () => HydrationTrend.empty,
        );
    final int goalMl =
        ref.watch(settingsProvider.select((AppSettings s) => s.waterGoalMl));

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RangeToggle(
            selected: range,
            onSelect: (int days) =>
                ref.read(hydrationRangeProvider.notifier).state = days,
          ),
          const SizedBox(height: 16),
          if (trend.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No water logged in the last $range days. Tap a quick-add '
                'button on the Today screen and this fills in.',
                style: AppText.caption,
              ),
            )
          else ...<Widget>[
            _AverageRow(trend: trend, goalMl: goalMl),
            const SizedBox(height: 3),
            Text(
              'averaged over ${trend.daysLogged} '
              'day${trend.daysLogged == 1 ? '' : 's'} logged of $range',
              style: AppText.caption,
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                _Stat(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.neonGreen,
                  value: '${trend.daysOnGoal} / ${trend.daysLogged}',
                  label: 'days on goal',
                ),
                _Stat(
                  icon: Icons.emoji_events_outlined,
                  color: AppColors.neonCyan,
                  value: formatWaterMl(trend.peakMl),
                  label: 'best day',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: DailyTargetBarChart(
                target: goalMl.toDouble(),
                lineColor: AppColors.neonGreen,
                bars: <DailyBar>[
                  for (final DailyHydration d in trend.days)
                    (
                      day: d.day,
                      value: d.totalMl.toDouble(),
                      logged: d.isLogged,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Container(
                  width: 14,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '${formatWaterMl(goalMl)} daily goal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({required this.trend, required this.goalMl});

  final HydrationTrend trend;
  final int goalMl;

  @override
  Widget build(BuildContext context) {
    final int delta = trend.averageMl - goalMl;

    // Both halves flex so the row can never overflow at a large text scale -
    // the lesson from the nutrition card's header.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  formatWaterMl(trend.averageMl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.metric,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('/ day', style: AppText.caption),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              delta >= 0
                  ? 'on goal'
                  : '${formatWaterMl(-delta)} under goal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: sora(
                11,
                600,
                color: delta >= 0 ? AppColors.neonGreen : AppColors.warning,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.22)),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sora(14, 700),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
