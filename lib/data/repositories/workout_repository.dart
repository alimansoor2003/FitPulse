import '../../core/utils/formatters.dart';
import '../../domain/models.dart';
import '../db/app_database.dart';

/// Application-facing API over the Drift database. Screens and providers talk
/// to this class only - never to raw tables.
class WorkoutRepository {
  WorkoutRepository(this.db);

  final AppDatabase db;

  // --------------------------------------------------------------- routine

  Stream<List<Exercise>> watchExercises(int dayIndex) =>
      db.watchExercises(dayIndex);

  Future<List<Exercise>> allExercises() => db.allExercises();

  // -------------------------------------------------------------- sessions

  Stream<WorkoutSession?> watchActiveSession() => db.watchActiveSession();

  Future<WorkoutSession?> activeSession() => db.activeSession();

  Future<WorkoutSession?> sessionById(int id) => db.sessionById(id);

  /// Resumes today's open session for [dayIndex] if there is one, otherwise
  /// creates a new session and pre-fills its prescribed set rows.
  Future<int> startOrResume(int dayIndex) async {
    final WorkoutSession? active = await db.activeSession();
    if (active != null && active.dayIndex == dayIndex) {
      await ensurePrescribedSets(active.id, dayIndex);
      return active.id;
    }
    if (active != null) {
      // Close the stale session before opening a different day.
      await db.finishSession(active.id);
    }
    final int id = await db.createSession(dayIndex);
    await ensurePrescribedSets(id, dayIndex);
    return id;
  }

  Future<void> finishSession(int id) => db.finishSession(id);

  Future<void> deleteSession(int id) => db.deleteSession(id);

  /// Creates the default set rows for any exercise in the day that has none.
  Future<void> ensurePrescribedSets(int sessionId, int dayIndex) async {
    final List<Exercise> exercises = await db.watchExercises(dayIndex).first;
    final List<SetLog> existing = await db.logsForSession(sessionId);

    for (final Exercise exercise in exercises) {
      final bool hasRows =
          existing.any((SetLog log) => log.exerciseId == exercise.id);
      if (hasRows) continue;
      for (int i = 1; i <= exercise.defaultSets; i++) {
        await db.insertSet(
          sessionId: sessionId,
          exerciseId: exercise.id,
          setIndex: i,
        );
      }
    }
  }

  // --------------------------------------------------------------- logging

  Stream<List<SetLog>> watchLogs(int sessionId) =>
      db.watchLogsForSession(sessionId);

  Future<void> updateSet(
    int id, {
    double? weightKg,
    int? reps,
    bool? completed,
  }) =>
      db.updateSet(id, weightKg: weightKg, reps: reps, completed: completed);

  Future<void> addSet(int sessionId, int exerciseId) async {
    final List<SetLog> logs = await db.logsForSession(sessionId);
    final Iterable<SetLog> forExercise =
        logs.where((SetLog l) => l.exerciseId == exerciseId);
    int next = 0;
    for (final SetLog log in forExercise) {
      if (log.setIndex > next) next = log.setIndex;
    }
    await db.insertSet(
      sessionId: sessionId,
      exerciseId: exerciseId,
      setIndex: next + 1,
    );
  }

  Future<void> deleteSet(int id) => db.deleteSet(id);

  // ------------------------------------------------- progressive overload

  /// Ghost values for [exerciseId]: what was lifted last time, per set slot.
  Future<List<GhostSet>> ghostSets(int exerciseId, int sessionId) async {
    final List<SetLog> previous = await db.previousLogs(exerciseId, sessionId);
    return previous
        .map((SetLog l) => GhostSet(weightKg: l.weightKg, reps: l.reps))
        .toList();
  }

  /// The suggested next target for a set slot: same reps at +[step] kg once
  /// the previous session's reps landed at or above [repFloor].
  GhostSet? suggestion(
    GhostSet? ghost, {
    double step = 2.5,
    int repFloor = 10,
  }) {
    if (ghost == null || ghost.weightKg <= 0 || ghost.reps <= 0) return null;
    if (ghost.reps >= repFloor) {
      return GhostSet(weightKg: ghost.weightKg + step, reps: ghost.reps);
    }
    return GhostSet(weightKg: ghost.weightKg, reps: ghost.reps + 1);
  }

  // -------------------------------------------------------------- analytics

  Stream<List<SessionSummary>> watchSessionSummaries() =>
      db.watchSessionSummaries();

  Future<List<ProgressPoint>> progressSeries(int exerciseId) =>
      db.progressSeries(exerciseId);

  Future<void> clearHistory() => db.clearHistory();

  Future<void> resetEverything() => db.resetEverything();

  /// Rolls session summaries up into the dashboard header numbers.
  DashboardStats statsFrom(List<SessionSummary> summaries, {int weeklyGoal = 3}) {
    if (summaries.isEmpty) {
      return DashboardStats.empty;
    }

    final DateTime weekStart = startOfWeek(DateTime.now());
    int sessionsThisWeek = 0;
    double volumeThisWeek = 0;
    double totalVolume = 0;
    int completedSets = 0;

    for (final SessionSummary s in summaries) {
      totalVolume += s.volumeKg;
      completedSets += s.completedSets;
      if (!s.startedAt.isBefore(weekStart)) {
        sessionsThisWeek++;
        volumeThisWeek += s.volumeKg;
      }
    }

    return DashboardStats(
      sessionsThisWeek: sessionsThisWeek,
      weeklyGoal: weeklyGoal,
      volumeThisWeekKg: volumeThisWeek,
      totalSessions: summaries.length,
      totalVolumeKg: totalVolume,
      streakWeeks: _streakWeeks(summaries),
      completedSets: completedSets,
      lastSession: summaries.first,
    );
  }

  /// Consecutive weeks (counting back from this week or last) that contain at
  /// least one session.
  int _streakWeeks(List<SessionSummary> summaries) {
    if (summaries.isEmpty) return 0;

    final Set<DateTime> weeks = summaries
        .map((SessionSummary s) => startOfWeek(s.startedAt))
        .toSet();

    DateTime cursor = startOfWeek(DateTime.now());
    if (!weeks.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 7));
      if (!weeks.contains(cursor)) return 0;
    }

    int streak = 0;
    while (weeks.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 7));
    }
    return streak;
  }

  /// Sessions and volume per week for the last [weeks] weeks, oldest first.
  List<WeeklyLoad> weeklyLoads(List<SessionSummary> summaries,
      {int weeks = 8}) {
    final DateTime thisWeek = startOfWeek(DateTime.now());
    final List<WeeklyLoad> result = <WeeklyLoad>[];

    for (int i = weeks - 1; i >= 0; i--) {
      final DateTime start = thisWeek.subtract(Duration(days: 7 * i));
      final DateTime end = start.add(const Duration(days: 7));
      int count = 0;
      double volume = 0;
      for (final SessionSummary s in summaries) {
        if (!s.startedAt.isBefore(start) && s.startedAt.isBefore(end)) {
          count++;
          volume += s.volumeKg;
        }
      }
      result.add(
        WeeklyLoad(weekStart: start, sessions: count, volumeKg: volume),
      );
    }
    return result;
  }
}
