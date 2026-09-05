import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_sheet.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/seed_data.dart';
import '../../../domain/models.dart';
import '../../../state/providers.dart';

/// Full breakdown of one finished session: every exercise and every set.
Future<void> showSessionDetailSheet(
  BuildContext context,
  SessionSummary summary,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC050A14),
    isScrollControlled: true,
    builder: (BuildContext context) => _SessionDetailSheet(summary: summary),
  );
}

class _SessionDetailSheet extends ConsumerWidget {
  const _SessionDetailSheet({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrainingDay day = trainingDay(summary.dayIndex);
    final List<SetLog> logs = ref.watch(sessionLogsProvider(summary.id)).maybeWhen(
          data: (List<SetLog> l) => l,
          orElse: () => const <SetLog>[],
        );
    final List<Exercise> exercises =
        ref.watch(allExercisesProvider).maybeWhen(
              data: (List<Exercise> e) => e,
              orElse: () => const <Exercise>[],
            );

    final List<Exercise> trained = exercises
        .where((Exercise e) => logs.any((SetLog l) => l.exerciseId == e.id))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSheet,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppColors.glassBorderBright),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(day.titleEn, style: AppText.title),
                        const SizedBox(height: 3),
                        Text(
                          '${friendlyDate(summary.startedAt)} - '
                          '${formatDuration(summary.duration)}',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete session',
                    onPressed: () async {
                      final bool confirmed = await showConfirmSheet(
                        context,
                        title: 'Delete this session?',
                        message:
                            'Every set logged in this session will be removed. '
                            'This cannot be undone.',
                        confirmLabel: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                      );
                      if (!confirmed) return;
                      await ref
                          .read(repositoryProvider)
                          .deleteSession(summary.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat(
                      label: 'Volume',
                      value: '${formatVolume(summary.volumeKg)} kg',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      label: 'Sets',
                      value: '${summary.completedSets}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      label: 'Exercises',
                      value: '${trained.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...trained.map((Exercise exercise) {
                final List<SetLog> sets = logs
                    .where((SetLog l) => l.exerciseId == exercise.id)
                    .toList()
                  ..sort((SetLog a, SetLog b) =>
                      a.setIndex.compareTo(b.setIndex));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(exercise.nameEn, style: sora(14, 600)),
                        const SizedBox(height: 2),
                        Text(
                          exercise.nameAr,
                          style: cairo(12, 400, color: AppColors.textTertiary),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sets.map((SetLog s) {
                            final bool done = s.completed;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: done
                                    ? AppColors.neonGreen.withOpacity(0.10)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: done
                                      ? AppColors.neonGreen.withOpacity(0.22)
                                      : AppColors.glassBorder,
                                ),
                              ),
                              child: Text(
                                '${formatWeight(s.weightKg)} kg x ${s.reps}',
                                style: sora(
                                  11,
                                  600,
                                  color: done
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: sora(15, 700)),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}
