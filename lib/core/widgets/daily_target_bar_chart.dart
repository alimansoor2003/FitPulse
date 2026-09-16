import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// One bar: a calendar day, its value, and whether anything was logged.
typedef DailyBar = ({DateTime day, double value, bool logged});

/// Daily bars against a dashed target line.
///
/// Shared by the nutrition and hydration trend cards. Plain fl_chart bars,
/// no live blur, so it is cheap to scroll past.
class DailyTargetBarChart extends StatelessWidget {
  const DailyTargetBarChart({
    super.key,
    required this.bars,
    required this.target,
    this.lineColor = AppColors.warning,
  });

  final List<DailyBar> bars;
  final double target;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    double peak = target;
    for (final DailyBar bar in bars) {
      if (bar.value > peak) peak = bar.value;
    }
    if (peak <= 0) peak = 1;

    // 30 bars cannot each carry a date, so label a handful of evenly spaced
    // days and leave the rest bare.
    final int labelStep = bars.length <= 8 ? 1 : (bars.length / 5).ceil();

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
            if (target > 0)
              HorizontalLine(
                y: target,
                color: lineColor.withOpacity(0.55),
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
                if (index < 0 || index >= bars.length) {
                  return const SizedBox.shrink();
                }
                // Always label the newest day, then step backwards.
                if ((bars.length - 1 - index) % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                final DateTime d = bars[index].day;
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
        barGroups: List<BarChartGroupData>.generate(bars.length, (int i) {
          final DailyBar bar = bars[i];
          return BarChartGroupData(
            x: i,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: bar.value,
                width: bars.length > 12 ? 6 : 13,
                borderRadius: BorderRadius.circular(4),
                // An unlogged day is drawn as an empty slot rather than as a
                // zero day, so a gap in the record does not read as a day of
                // not eating or not drinking.
                color: bar.logged ? null : Colors.white.withOpacity(0.05),
                gradient: bar.logged
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
                  show: !bar.logged,
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
