import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../core/widgets/tick_gauge.dart';
import '../../data/db/app_database.dart';
import '../../data/db/seed_data.dart';
import '../../state/providers.dart';
import '../../state/rest_timer.dart';
import '../../state/settings_controller.dart';
import 'widgets/exercise_card.dart';
import 'widgets/rest_timer_bar.dart';

/// The active training session: log every set, watch the meter fill.
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({
    super.key,
    required this.sessionId,
    required this.dayIndex,
  });

  final int sessionId;
  final int dayIndex;

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    List<SetLog> logs,
  ) async {
    final int done = logs.where((SetLog l) => l.completed).length;
    // A set can hold a typed weight/reps without being ticked complete -
    // that's still real data, and discarding it would be silent data loss.
    final bool hasAnyData = logs.any(
      (SetLog l) => l.completed || l.weightKg > 0 || l.reps > 0,
    );

    final bool confirmed = await showConfirmSheet(
      context,
      title: hasAnyData ? 'Finish workout?' : 'Discard this session?',
      message: !hasAnyData
          ? 'Nothing has been logged yet, so this session will be removed.'
          : done > 0
              ? 'You logged $done ${done == 1 ? 'set' : 'sets'}. It will be '
                  'saved to your history and used as the target next time.'
              : 'You entered numbers but did not tick any sets complete. '
                  "They'll still be saved - tick them off if you finished "
                  'them.',
      confirmLabel: hasAnyData ? 'Finish' : 'Discard',
      icon: hasAnyData ? Icons.flag_rounded : Icons.delete_outline_rounded,
      destructive: !hasAnyData,
    );
    if (!confirmed) return;

    if (!hasAnyData) {
      await ref.read(repositoryProvider).deleteSession(sessionId);
    } else {
      await ref.read(repositoryProvider).finishSession(sessionId);
    }
    ref.read(restTimerProvider.notifier).stop();

    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrainingDay day = trainingDay(dayIndex);
    final AsyncValue<List<Exercise>> exercisesAsync =
        ref.watch(exercisesProvider(dayIndex));
    final AsyncValue<List<SetLog>> logsAsync =
        ref.watch(sessionLogsProvider(sessionId));
    final AsyncValue<WorkoutSession?> sessionAsync =
        ref.watch(sessionByIdProvider(sessionId));
    final bool showArabic = ref.watch(
      settingsProvider.select((AppSettings s) => s.showArabicNames),
    );

    final List<Exercise> exercises = exercisesAsync.maybeWhen(
      data: (List<Exercise> e) => e,
      orElse: () => const <Exercise>[],
    );
    final List<SetLog> logs = logsAsync.maybeWhen(
      data: (List<SetLog> l) => l,
      orElse: () => const <SetLog>[],
    );

    final int doneSets = logs.where((SetLog l) => l.completed).length;
    final bool hasLoggedData = logs.any(
      (SetLog l) => l.completed || l.weightKg > 0 || l.reps > 0,
    );
    final double progress = logs.isEmpty ? 0 : doneSets / logs.length;
    final double volume = logs
        .where((SetLog l) => l.completed)
        .fold<double>(0, (double sum, SetLog l) => sum + l.weightKg * l.reps);

    final DateTime startedAt = sessionAsync.maybeWhen(
      data: (WorkoutSession? s) => s?.startedAt ?? DateTime.now(),
      orElse: DateTime.now,
    );

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _Header(day: day, showArabic: showArabic),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  children: <Widget>[
                    FadeIn(
                      child: _SessionMeter(
                        progress: progress,
                        doneSets: doneSets,
                        totalSets: logs.length,
                        volumeKg: volume,
                        startedAt: startedAt,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (exercises.isEmpty)
                      const _LoadingHint()
                    else
                      ...List<Widget>.generate(exercises.length, (int i) {
                        final Exercise exercise = exercises[i];
                        final List<SetLog> forExercise = logs
                            .where((SetLog l) => l.exerciseId == exercise.id)
                            .toList()
                          ..sort((SetLog a, SetLog b) =>
                              a.setIndex.compareTo(b.setIndex));
                        return FadeIn(
                          delay: Duration(milliseconds: 60 + i * 40),
                          child: ExerciseCard(
                            exercise: exercise,
                            sessionId: sessionId,
                            logs: forExercise,
                          ),
                        );
                      }),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const RestTimerBar(),
                    NeonButton(
                      label: hasLoggedData ? 'FINISH WORKOUT' : 'DISCARD SESSION',
                      icon: Icons.check_rounded,
                      onPressed: () => _finish(context, ref, logs),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.day, required this.showArabic});

  final TrainingDay day;
  final bool showArabic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        children: <Widget>[
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Today - Day ${day.index}', style: AppText.caption),
                const SizedBox(height: 2),
                Text(day.titleEn, style: sora(19, 700, letterSpacing: -0.3)),
                if (showArabic)
                  Text(
                    day.titleAr,
                    style: cairo(12, 400, color: AppColors.textTertiary),
                    textDirection: TextDirection.rtl,
                  ),
              ],
            ),
          ),
          GlassIconButton(
            icon: Icons.home_rounded,
            tooltip: 'Home',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _SessionMeter extends ConsumerWidget {
  const _SessionMeter({
    required this.progress,
    required this.doneSets,
    required this.totalSets,
    required this.volumeKg,
    required this.startedAt,
  });

  final double progress;
  final int doneSets;
  final int totalSets;
  final double volumeKg;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds once per second so the elapsed time stays live.
    ref.watch(clockProvider);
    final Duration elapsed = DateTime.now().difference(startedAt);

    return GlassCard(
      highlighted: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Track Record', style: sora(13, 600)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.neonGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Live', style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TickGauge(
            value: progress,
            size: 190,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${(progress * 100).round()}%',
                  style: sora(34, 700, letterSpacing: -1.4),
                ),
                Text('Progress', style: AppText.label),
                const SizedBox(height: 4),
                Text('$doneSets of $totalSets sets', style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  icon: Icons.schedule_rounded,
                  label: 'Duration',
                  value: formatDuration(elapsed),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  icon: Icons.scale_rounded,
                  label: 'Volume',
                  value: '${formatVolume(volumeKg)} kg',
                  accent: AppColors.neonGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.neonCyan,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AppText.caption),
                const SizedBox(height: 1),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: sora(14, 700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingHint extends StatelessWidget {
  const _LoadingHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonCyan),
          ),
        ),
      ),
    );
  }
}
