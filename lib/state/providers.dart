import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/workout_repository.dart';
import '../domain/models.dart';
import 'settings_controller.dart';

/// Single database instance for the app lifetime.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final Provider<WorkoutRepository> repositoryProvider =
    Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(databaseProvider)),
);

/// Exercises for one training day (1-3).
final exercisesProvider = StreamProvider.family<List<Exercise>, int>(
  (ref, int dayIndex) => ref.watch(repositoryProvider).watchExercises(dayIndex),
);

/// The single open (unfinished) session, if any.
final StreamProvider<WorkoutSession?> activeSessionProvider =
    StreamProvider<WorkoutSession?>(
  (ref) => ref.watch(repositoryProvider).watchActiveSession(),
);

/// Every set logged inside one session.
final sessionLogsProvider = StreamProvider.family<List<SetLog>, int>(
  (ref, int sessionId) => ref.watch(repositoryProvider).watchLogs(sessionId),
);

/// A single session by id - used by the workout and history detail screens.
final sessionByIdProvider = FutureProvider.family<WorkoutSession?, int>(
  (ref, int id) => ref.watch(repositoryProvider).sessionById(id),
);

final StreamProvider<List<SessionSummary>> sessionSummariesProvider =
    StreamProvider<List<SessionSummary>>(
  (ref) => ref.watch(repositoryProvider).watchSessionSummaries(),
);

/// Only sessions that were actually finished - used by the history screen.
final Provider<List<SessionSummary>> finishedSessionsProvider =
    Provider<List<SessionSummary>>((ref) {
  final AsyncValue<List<SessionSummary>> async =
      ref.watch(sessionSummariesProvider);
  return async.maybeWhen(
    data: (List<SessionSummary> list) =>
        list.where((SessionSummary s) => !s.isActive).toList(),
    orElse: () => const <SessionSummary>[],
  );
});

final Provider<DashboardStats> dashboardStatsProvider =
    Provider<DashboardStats>((ref) {
  final List<SessionSummary> finished = ref.watch(finishedSessionsProvider);
  final int goal = ref.watch(settingsProvider).weeklyGoal;
  return ref.watch(repositoryProvider).statsFrom(finished, weeklyGoal: goal);
});

final Provider<List<WeeklyLoad>> weeklyLoadProvider =
    Provider<List<WeeklyLoad>>((ref) {
  final List<SessionSummary> finished = ref.watch(finishedSessionsProvider);
  return ref.watch(repositoryProvider).weeklyLoads(finished);
});

/// Key for the ghost-value lookup: an exercise inside a specific session.
typedef GhostKey = ({int exerciseId, int sessionId});

/// Previous session's numbers for an exercise, shown as placeholder hints.
final ghostSetsProvider = FutureProvider.family<List<GhostSet>, GhostKey>(
  (ref, GhostKey key) => ref
      .watch(repositoryProvider)
      .ghostSets(key.exerciseId, key.sessionId),
);

final progressSeriesProvider = FutureProvider.family<List<ProgressPoint>, int>(
  (ref, int exerciseId) =>
      ref.watch(repositoryProvider).progressSeries(exerciseId),
);

final FutureProvider<List<Exercise>> allExercisesProvider =
    FutureProvider<List<Exercise>>(
  (ref) => ref.watch(repositoryProvider).allExercises(),
);

/// One-second ticker driving the live session duration readout.
final StreamProvider<DateTime> clockProvider = StreamProvider<DateTime>(
  (ref) => Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  ),
);

/// Which training day the user last opened (pure UI state, manual selection).
final StateProvider<int> selectedDayProvider = StateProvider<int>((ref) => 1);

/// Selected bottom-navigation tab, so any screen can jump to another one.
final StateProvider<int> shellTabProvider = StateProvider<int>((ref) => 0);
