import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/app_database.dart';
import '../../data/db/seed_data.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import 'widgets/session_detail_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final List<SessionSummary> sessions = ref.watch(finishedSessionsProvider);
    final DashboardStats stats = ref.watch(dashboardStatsProvider);
    final List<WeeklyLoad> weeks = ref.watch(weeklyLoadProvider);
    final AsyncValue<List<Exercise>> exercisesAsync =
        ref.watch(allExercisesProvider);
    final List<Exercise> exercises = exercisesAsync.maybeWhen(
      data: (List<Exercise> e) => e,
      orElse: () => const <Exercise>[],
    );

    final int? exerciseId = _selectedExerciseId ??
        (exercises.isEmpty ? null : exercises.first.id);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 18,
        20,
        120,
      ),
      children: <Widget>[
        FadeIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Progress', style: AppText.display),
              const SizedBox(height: 4),
              Text(
                'Every session you have banked so far.',
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        FadeIn(
          delay: const Duration(milliseconds: 60),
          child: _SummaryGrid(stats: stats),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Weekly Consistency'),
        FadeIn(
          delay: const Duration(milliseconds: 100),
          child: _ConsistencyStrip(weeks: weeks, goal: stats.weeklyGoal),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Session Volume'),
        FadeIn(
          delay: const Duration(milliseconds: 140),
          child: _VolumeChartCard(sessions: sessions),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Strength Progression'),
        FadeIn(
          delay: const Duration(milliseconds: 180),
          child: _ProgressionCard(
            exercises: exercises,
            selectedId: exerciseId,
            onSelect: (int id) => setState(() => _selectedExerciseId = id),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'All Sessions'),
        if (sessions.isEmpty)
          GlassCard(
            child: Text(
              'Nothing logged yet. Finish a workout and it will show up here '
              'with its volume, duration and set count.',
              style: AppText.caption,
            ),
          )
        else
          ...sessions.map(
            (SessionSummary s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HistoryRow(
                summary: s,
                onTap: () => showSessionDetailSheet(context, s),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryTile(
            icon: Icons.calendar_month_rounded,
            value: '${stats.totalSessions}',
            label: 'Sessions',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.scale_rounded,
            value: '${formatVolume(stats.totalVolumeKg)} kg',
            label: 'Total volume',
            accent: AppColors.neonBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            icon: Icons.local_fire_department_rounded,
            value: '${stats.streakWeeks}w',
            label: 'Streak',
            accent: AppColors.neonGreen,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: accent),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: sora(17, 700, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}

class _ConsistencyStrip extends StatelessWidget {
  const _ConsistencyStrip({required this.weeks, required this.goal});

  final List<WeeklyLoad> weeks;
  final int goal;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Last ${weeks.length} weeks', style: AppText.caption),
          const SizedBox(height: 14),
          SizedBox(
            height: 74,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeks.map((WeeklyLoad w) {
                final double ratio =
                    goal == 0 ? 0 : (w.sessions / goal).clamp(0.0, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text('${w.sessions}', style: AppText.caption),
                        const SizedBox(height: 5),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: ratio),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (BuildContext context, double value,
                              Widget? _) {
                            return Container(
                              height: 12 + 34 * value,
                              decoration: BoxDecoration(
                                gradient: value > 0
                                    ? AppColors.accentGradient
                                    : null,
                                color: value > 0
                                    ? null
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${w.weekStart.day}/${w.weekStart.month}',
                          style: sora(9, 400, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeChartCard extends StatelessWidget {
  const _VolumeChartCard({required this.sessions});

  final List<SessionSummary> sessions;

  @override
  Widget build(BuildContext context) {
    // Oldest to newest, last 8 sessions.
    final List<SessionSummary> data =
        sessions.take(8).toList().reversed.toList();

    if (data.isEmpty) {
      return GlassCard(
        child: Text(
          'Volume per session appears here once you finish your first '
          'workout.',
          style: AppText.caption,
        ),
      );
    }

    final double maxVolume = data
        .map((SessionSummary s) => s.volumeKg)
        .fold<double>(0, (double a, double b) => a > b ? a : b);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 18, 18, 10),
      child: SizedBox(
        height: 190,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVolume <= 0 ? 10 : maxVolume * 1.25,
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
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        shortDate(data[index].startedAt),
                        style: sora(9, 400, color: AppColors.textTertiary),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List<BarChartGroupData>.generate(data.length, (int i) {
              return BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: data[i].volumeKg,
                    width: 14,
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[AppColors.neonBlue, AppColors.neonCyan],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ProgressionCard extends ConsumerWidget {
  const _ProgressionCard({
    required this.exercises,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Exercise> exercises;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exercises.isEmpty || selectedId == null) {
      return GlassCard(
        child: Text('Loading your exercises...', style: AppText.caption),
      );
    }

    final AsyncValue<List<ProgressPoint>> seriesAsync =
        ref.watch(progressSeriesProvider(selectedId!));
    final List<ProgressPoint> series = seriesAsync.maybeWhen(
      data: (List<ProgressPoint> p) => p,
      orElse: () => const <ProgressPoint>[],
    );

    final double first =
        series.isEmpty ? 0 : series.first.estimatedOneRm;
    final double last = series.isEmpty ? 0 : series.last.estimatedOneRm;
    final double delta = last - first;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: exercises.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int i) {
                final Exercise e = exercises[i];
                final bool selected = e.id == selectedId;
                return GestureDetector(
                  onTap: () => onSelect(e.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: selected ? AppColors.accentGradient : null,
                      color: selected ? null : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      e.nameEn,
                      style: sora(
                        11,
                        600,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          if (series.length < 2)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  series.isEmpty
                      ? 'No completed sets for this exercise yet.'
                      : 'Log this exercise once more to draw the trend.',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
            )
          else ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${last.toStringAsFixed(1)} kg',
                  style: sora(24, 700, letterSpacing: -1),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'est. 1RM',
                    style: AppText.caption,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (delta >= 0 ? AppColors.neonGreen : AppColors.danger)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                    style: sora(
                      11,
                      700,
                      color: delta >= 0
                          ? AppColors.neonGreen
                          : AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (double value) => FlLine(
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (series.length / 4).ceilToDouble(),
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.round();
                          if (index < 0 || index >= series.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortDate(series[index].date),
                              style: sora(
                                9,
                                400,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(enabled: false),
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      spots: List<FlSpot>.generate(
                        series.length,
                        (int i) => FlSpot(
                          i.toDouble(),
                          series[i].estimatedOneRm,
                        ),
                      ),
                      isCurved: true,
                      curveSmoothness: 0.28,
                      barWidth: 3,
                      gradient: const LinearGradient(
                        colors: <Color>[
                          AppColors.neonBlue,
                          AppColors.neonCyan,
                        ],
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (
                          FlSpot spot,
                          double percent,
                          LineChartBarData bar,
                          int index,
                        ) {
                          return FlDotCirclePainter(
                            radius: 3.5,
                            color: AppColors.neonCyan,
                            strokeWidth: 2,
                            strokeColor: AppColors.bgDeep,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            AppColors.neonBlue.withOpacity(0.28),
                            AppColors.neonBlue.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.summary, required this.onTap});

  final SessionSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TrainingDay day = trainingDay(summary.dayIndex);
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.2)),
            ),
            child: Text(
              'D${summary.dayIndex}',
              style: sora(13, 700, color: AppColors.neonCyan),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(day.titleEn, style: sora(13, 600)),
                const SizedBox(height: 2),
                Text(
                  '${friendlyDate(summary.startedAt)} - '
                  '${summary.completedSets} sets - '
                  '${formatDuration(summary.duration)}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text(
            '${formatVolume(summary.volumeKg)} kg',
            style: sora(13, 700, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
