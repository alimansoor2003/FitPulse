import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../domain/models.dart';
import '../../../state/providers.dart';
import '../../../state/rest_timer.dart';
import '../../../state/settings_controller.dart';
import 'set_row.dart';

/// A single exercise inside the active session: its prescribed sets, the
/// ghost values from last time, and the suggested next target.
class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.sessionId,
    required this.logs,
  });

  final Exercise exercise;
  final int sessionId;
  final List<SetLog> logs;

  GhostSet? _ghostFor(List<GhostSet> ghosts, int setIndex) {
    if (ghosts.isEmpty) return null;
    if (setIndex - 1 < ghosts.length) return ghosts[setIndex - 1];
    return ghosts.last;
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    SetLog log,
  ) async {
    final bool next = !log.completed;

    if (next && log.reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the reps you hit before ticking the set off.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await ref.read(repositoryProvider).updateSet(log.id, completed: next);

    if (!next) return;

    HapticFeedback.mediumImpact();
    final AppSettings settings = ref.read(settingsProvider);
    if (settings.autoStartRest) {
      final int seconds = exercise.restSeconds > 0
          ? exercise.restSeconds
          : settings.defaultRestSeconds;
      ref
          .read(restTimerProvider.notifier)
          .start(seconds, label: exercise.nameEn);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final bool showArabic = settings.showArabicNames;
    final AsyncValue<List<GhostSet>> ghostsAsync = ref.watch(
      ghostSetsProvider((exerciseId: exercise.id, sessionId: sessionId)),
    );
    final List<GhostSet> ghosts =
        ghostsAsync.maybeWhen(data: (List<GhostSet> g) => g, orElse: () => const <GhostSet>[]);

    final int doneCount =
        logs.where((SetLog l) => l.completed).length;
    final bool allDone = logs.isNotEmpty && doneCount == logs.length;

    // Captured once so the set-row callbacks hold the repository itself
    // rather than `ref` - a queued write may still need to flush while the
    // row is being disposed, when reading from `ref` is no longer valid.
    final WorkoutRepository repo = ref.read(repositoryProvider);

    final GhostSet? suggestion = repo.suggestion(
      ghosts.isEmpty ? null : ghosts.first,
      step: settings.weightStep,
    );

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      highlighted: allDone,
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
                    Text(exercise.nameEn, style: sora(15, 600, height: 1.25)),
                    if (showArabic) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        exercise.nameAr,
                        style: cairo(12.5, 400, color: AppColors.textTertiary),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: allDone
                      ? AppColors.neonGreen.withOpacity(0.14)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$doneCount/${logs.length}',
                  style: sora(
                    11,
                    700,
                    color: allDone
                        ? AppColors.neonGreen
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HintRow(
            targetLabel: exercise.targetLabel,
            ghost: ghosts.isEmpty ? null : ghosts.first,
            suggestion: suggestion,
          ),
          const SizedBox(height: 14),
          ...logs.map((SetLog log) {
            return Dismissible(
              key: ValueKey<int>(log.id),
              direction: logs.length > 1
                  ? DismissDirection.endToStart
                  : DismissDirection.none,
              background: const _DeleteBackground(),
              onDismissed: (_) {
                HapticFeedback.lightImpact();
                repo.deleteSet(log.id);
              },
              child: SetRow(
                log: log,
                ghost: _ghostFor(ghosts, log.setIndex),
                onWeightChanged: (double value) =>
                    repo.updateSet(log.id, weightKg: value),
                onRepsChanged: (int value) =>
                    repo.updateSet(log.id, reps: value),
                onToggle: () => _toggle(context, ref, log),
              ),
            );
          }),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  repo.addSet(sessionId, exercise.id);
                },
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text('Add set', style: sora(12, 600)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neonCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (logs.length > 1)
                Text('Swipe a set to remove', style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.targetLabel,
    required this.ghost,
    required this.suggestion,
  });

  final String targetLabel;
  final GhostSet? ghost;
  final GhostSet? suggestion;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _Pill(
          icon: Icons.repeat_rounded,
          label: targetLabel,
          color: AppColors.textSecondary,
        ),
        if (ghost != null)
          _Pill(
            icon: Icons.history_rounded,
            label:
                'Last ${formatWeight(ghost!.weightKg)} kg x ${ghost!.reps}',
            color: AppColors.textSecondary,
          ),
        if (suggestion != null)
          _Pill(
            icon: Icons.trending_up_rounded,
            label:
                'Target ${formatWeight(suggestion!.weightKg)} kg x ${suggestion!.reps}',
            color: AppColors.neonCyan,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: sora(11, 500, color: color)),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(right: 18),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: AppColors.danger,
        size: 20,
      ),
    );
  }
}
