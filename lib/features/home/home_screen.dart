import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_header.dart';
import '../../data/db/app_database.dart';
import '../../data/db/seed_data.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../workout/workout_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openDay(
    BuildContext context,
    WidgetRef ref,
    int dayIndex,
  ) async {
    final TrainingDay day = trainingDay(dayIndex);
    if (day.isRest) {
      await showConfirmSheet(
        context,
        title: 'Rest Day',
        message:
            'No training scheduled. Recovery is where the adaptation happens - '
            'eat, sleep, and come back stronger tomorrow.',
        confirmLabel: 'Got it',
        cancelLabel: 'Close',
        icon: Icons.bedtime_rounded,
      );
      return;
    }

    ref.read(selectedDayProvider.notifier).state = dayIndex;

    final WorkoutSession? active =
        await ref.read(repositoryProvider).activeSession();

    if (active != null && active.dayIndex != dayIndex) {
      if (!context.mounted) return;
      final bool proceed = await showConfirmSheet(
        context,
        title: 'Finish the open session?',
        message:
            '${trainingDay(active.dayIndex).titleEn} is still in progress. '
            'Starting ${day.titleEn} will close it and keep everything you '
            'have already logged.',
        confirmLabel: 'Start new',
        icon: Icons.swap_horiz_rounded,
      );
      if (!proceed) return;
    }

    final int sessionId =
        await ref.read(repositoryProvider).startOrResume(dayIndex);

    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutScreen(sessionId: sessionId, dayIndex: dayIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final DashboardStats stats = ref.watch(dashboardStatsProvider);
    final List<SessionSummary> finished = ref.watch(finishedSessionsProvider);
    final AsyncValue<WorkoutSession?> active =
        ref.watch(activeSessionProvider);
    final int selectedDay = ref.watch(selectedDayProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 18,
        20,
        120,
      ),
      children: <Widget>[
        FadeIn(child: _Greeting(name: settings.userName, stats: stats)),
        const SizedBox(height: 24),

        active.maybeWhen(
          data: (WorkoutSession? session) => session == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: FadeIn(
                    delay: const Duration(milliseconds: 60),
                    child: _ResumeBanner(
                      session: session,
                      onResume: () => _openDay(context, ref, session.dayIndex),
                    ),
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),

        const SectionHeader(title: 'My Health'),
        FadeIn(
          delay: const Duration(milliseconds: 90),
          child: _WeeklyStatsRow(
            stats: stats,
            onNewSession: () => _openDay(context, ref, selectedDay),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Active Task'),
        FadeIn(
          delay: const Duration(milliseconds: 140),
          child: _FocusCard(
            dayIndex: selectedDay,
            stats: stats,
            showArabic: settings.showArabicNames,
            onStart: () => _openDay(context, ref, selectedDay),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Training Split'),
        ...List<Widget>.generate(kTrainingDays.length, (int i) {
          final TrainingDay day = kTrainingDays[i];
          return FadeIn(
            delay: Duration(milliseconds: 180 + i * 45),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DayTile(
                day: day,
                selected: day.index == selectedDay,
                showArabic: settings.showArabicNames,
                onTap: () => _openDay(context, ref, day.index),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),

        SectionHeader(
          title: 'Previous Tasks',
          actionLabel: finished.isEmpty ? null : 'View All',
          onAction: () => ref.read(shellTabProvider.notifier).state = 1,
        ),
        if (finished.isEmpty)
          const _EmptyHistoryHint()
        else
          ...finished.take(3).map(
                (SessionSummary s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionRow(summary: s),
                ),
              ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.stats});

  final String name;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Hi $name,', style: AppText.display),
              Text(
                'Welcome!',
                style: sora(30, 700, letterSpacing: -0.6, height: 1.15),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GlassCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.local_fire_department_rounded,
                size: 17,
                color: AppColors.neonCyan,
              ),
              const SizedBox(width: 6),
              Text('${stats.streakWeeks}w', style: sora(13, 700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.session, required this.onResume});

  final WorkoutSession session;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final TrainingDay day = trainingDay(session.dayIndex);
    return GlassCard(
      highlighted: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      onTap: onResume,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Session in progress', style: sora(14, 600)),
                const SizedBox(height: 2),
                Text(
                  '${day.titleEn} - started ${friendlyDate(session.startedAt).toLowerCase()}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.neonCyan,
          ),
        ],
      ),
    );
  }
}

class _WeeklyStatsRow extends StatelessWidget {
  const _WeeklyStatsRow({required this.stats, required this.onNewSession});

  final DashboardStats stats;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Weekly Stats', style: sora(13, 600)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      MiniStat(
                        icon: Icons.calendar_month_rounded,
                        value: '${stats.sessionsThisWeek}/${stats.weeklyGoal}',
                        label: 'Sessions',
                      ),
                      MiniStat(
                        icon: Icons.scale_rounded,
                        value: formatVolume(stats.volumeThisWeekKg),
                        label: 'Volume',
                        accent: AppColors.neonBlue,
                      ),
                      MiniStat(
                        icon: Icons.check_circle_outline_rounded,
                        value: '${stats.completedSets}',
                        label: 'Sets',
                        accent: AppColors.neonGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              onTap: onNewSession,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.neonBlue.withOpacity(0.4),
                          blurRadius: 18,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 21),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Start\nSession',
                    textAlign: TextAlign.center,
                    style: sora(11, 500, color: AppColors.textSecondary,
                        height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.dayIndex,
    required this.stats,
    required this.showArabic,
    required this.onStart,
  });

  final int dayIndex;
  final DashboardStats stats;
  final bool showArabic;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final TrainingDay day = trainingDay(dayIndex);

    return GlassCard(
      highlighted: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Day $dayIndex', style: AppText.caption),
                    const SizedBox(height: 4),
                    Text(day.titleEn, style: AppText.title),
                    if (showArabic) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        day.titleAr,
                        style: cairo(13, 500),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ],
                ),
              ),
              ProgressRing(
                value: stats.weeklyProgress,
                size: 74,
                stroke: 7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${(stats.weeklyProgress * 100).round()}%',
                      style: sora(15, 700),
                    ),
                    Text('week', style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              _Chip(
                icon: Icons.bolt_rounded,
                label: '${stats.streakWeeks} week streak',
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.fitness_center_rounded,
                label: day.subtitle,
              ),
            ],
          ),
          const SizedBox(height: 18),
          NeonButton(
            label: day.isRest ? 'REST DAY' : 'START WORKOUT',
            icon: day.isRest
                ? Icons.bedtime_rounded
                : Icons.arrow_forward_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: AppColors.neonCyan),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: sora(11, 500, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.selected,
    required this.showArabic,
    required this.onTap,
  });

  final TrainingDay day;
  final bool selected;
  final bool showArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        day.isRest ? AppColors.textSecondary : AppColors.neonCyan;

    return GlassCard(
      onTap: onTap,
      highlighted: selected,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(selected ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accent.withOpacity(0.22)),
            ),
            child: Center(
              child: day.isRest
                  ? const Icon(Icons.bedtime_rounded,
                      size: 19, color: AppColors.textSecondary)
                  : Text('${day.index}', style: sora(16, 700, color: accent)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(day.titleEn, style: sora(14, 600)),
                const SizedBox(height: 3),
                if (showArabic)
                  Text(
                    day.titleAr,
                    style: cairo(12, 400, color: AppColors.textTertiary),
                    textDirection: TextDirection.rtl,
                  )
                else
                  Text(day.subtitle, style: AppText.caption),
              ],
            ),
          ),
          Icon(
            day.isRest
                ? Icons.nightlight_round
                : Icons.play_circle_fill_rounded,
            color: selected ? AppColors.neonCyan : AppColors.textTertiary,
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final TrainingDay day = trainingDay(summary.dayIndex);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          ProgressRing(
            value: 1,
            size: 40,
            stroke: 3.5,
            child: Text(
              '${summary.completedSets}',
              style: sora(12, 700),
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
                  '${formatVolume(summary.volumeKg)} kg volume',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text(
            formatDuration(summary.duration),
            style: sora(12, 600, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryHint extends StatelessWidget {
  const _EmptyHistoryHint();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.timeline_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No sessions logged yet. Finish your first workout and your '
              'history will build from here.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
