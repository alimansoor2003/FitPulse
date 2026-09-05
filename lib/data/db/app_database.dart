import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models.dart';
import 'seed_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: <Type>[Exercises, WorkoutSessions, SetLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory constructor for tests.
  AppDatabase.withExecutor(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await seedIfEmpty();
        },
      );

  // ---------------------------------------------------------------- seeding

  Future<void> seedIfEmpty() async {
    final int count = await exerciseCount();
    if (count > 0) return;
    await batch((Batch b) {
      b.insertAll(
        exercises,
        kSeedExercises
            .map(
              (SeedExercise e) => ExercisesCompanion.insert(
                dayIndex: e.dayIndex,
                nameEn: e.nameEn,
                nameAr: e.nameAr,
                orderIndex: e.orderIndex,
                targetLabel: Value<String>(e.targetLabel),
                defaultSets: Value<int>(e.defaultSets),
                restSeconds: Value<int>(e.restSeconds),
              ),
            )
            .toList(),
      );
    });
  }

  Future<int> exerciseCount() async {
    final Expression<int> countAll = exercises.id.count();
    final query = selectOnly(exercises)
      ..addColumns(<Expression<Object>>[countAll]);
    final TypedResult row = await query.getSingle();
    return row.read(countAll) ?? 0;
  }

  // -------------------------------------------------------------- exercises

  Stream<List<Exercise>> watchExercises(int dayIndex) {
    return (select(exercises)
          ..where((t) =>
              t.dayIndex.equals(dayIndex) & t.archived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.orderIndex),
          ]))
        .watch();
  }

  Future<List<Exercise>> allExercises() {
    return (select(exercises)
          ..where((t) => t.archived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.dayIndex),
            (t) => OrderingTerm.asc(t.orderIndex),
          ]))
        .get();
  }

  // --------------------------------------------------------------- sessions

  Stream<WorkoutSession?> watchActiveSession() {
    return (select(workoutSessions)
          ..where((t) => t.finishedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.startedAt),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<WorkoutSession?> activeSession() {
    return (select(workoutSessions)
          ..where((t) => t.finishedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.startedAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<WorkoutSession?> sessionById(int id) {
    return (select(workoutSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> createSession(int dayIndex) {
    return into(workoutSessions).insert(
      WorkoutSessionsCompanion.insert(
        dayIndex: dayIndex,
        startedAt: DateTime.now(),
      ),
    );
  }

  Future<void> finishSession(int id) async {
    await (update(workoutSessions)
          ..where((t) => t.id.equals(id)))
        .write(
      WorkoutSessionsCompanion(finishedAt: Value<DateTime?>(DateTime.now())),
    );
  }

  Future<void> deleteSession(int id) async {
    await (delete(setLogs)..where((t) => t.sessionId.equals(id))).go();
    await (delete(workoutSessions)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // ---------------------------------------------------------------- logging

  Stream<List<SetLog>> watchLogsForSession(int sessionId) {
    return (select(setLogs)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.exerciseId),
            (t) => OrderingTerm.asc(t.setIndex),
          ]))
        .watch();
  }

  Future<List<SetLog>> logsForSession(int sessionId) {
    return (select(setLogs)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.exerciseId),
            (t) => OrderingTerm.asc(t.setIndex),
          ]))
        .get();
  }

  Future<int> insertSet({
    required int sessionId,
    required int exerciseId,
    required int setIndex,
    double weightKg = 0,
    int reps = 0,
  }) {
    return into(setLogs).insert(
      SetLogsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setIndex: setIndex,
        weightKg: Value<double>(weightKg),
        reps: Value<int>(reps),
      ),
    );
  }

  Future<void> updateSet(
    int id, {
    double? weightKg,
    int? reps,
    bool? completed,
  }) async {
    await (update(setLogs)..where((t) => t.id.equals(id))).write(
      SetLogsCompanion(
        weightKg: weightKg == null
            ? const Value<double>.absent()
            : Value<double>(weightKg),
        reps: reps == null ? const Value<int>.absent() : Value<int>(reps),
        completed: completed == null
            ? const Value<bool>.absent()
            : Value<bool>(completed),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSet(int id) async {
    await (delete(setLogs)..where((t) => t.id.equals(id))).go();
  }

  /// Logged sets from the most recent *other* session that trained
  /// [exerciseId] - the source of the ghost/placeholder values.
  Future<List<SetLog>> previousLogs(int exerciseId, int excludeSessionId) async {
    final List<SetLog> rows = await (select(setLogs)
          ..where((t) =>
              t.exerciseId.equals(exerciseId) &
              t.completed.equals(true) &
              t.sessionId.equals(excludeSessionId).not()))
        .get();
    if (rows.isEmpty) return <SetLog>[];

    // Session ids auto-increment, so the largest id is the most recent one.
    int latest = rows.first.sessionId;
    for (final SetLog row in rows) {
      if (row.sessionId > latest) latest = row.sessionId;
    }
    final List<SetLog> previous =
        rows.where((SetLog r) => r.sessionId == latest).toList();
    previous.sort((SetLog a, SetLog b) => a.setIndex.compareTo(b.setIndex));
    return previous;
  }

  // -------------------------------------------------------------- analytics

  static const String _summarySql =
      'SELECT s.id AS id, s.day_index AS day_index, s.started_at AS started_at, '
      's.finished_at AS finished_at, '
      'COALESCE(SUM(CASE WHEN l.completed = 1 THEN l.weight_kg * l.reps END), 0.0) AS volume, '
      'COALESCE(SUM(CASE WHEN l.completed = 1 THEN 1 END), 0) AS set_count '
      'FROM workout_sessions s LEFT JOIN set_logs l ON l.session_id = s.id '
      'GROUP BY s.id ORDER BY s.started_at DESC LIMIT ?';

  Stream<List<SessionSummary>> watchSessionSummaries({int limit = 200}) {
    return customSelect(
      _summarySql,
      variables: [Variable<int>(limit)],
      readsFrom: {workoutSessions, setLogs},
    ).watch().map(
          (List<QueryRow> rows) => rows.map(_summaryFromRow).toList(),
        );
  }

  Future<List<SessionSummary>> sessionSummaries({int limit = 200}) async {
    final List<QueryRow> rows = await customSelect(
      _summarySql,
      variables: [Variable<int>(limit)],
      readsFrom: {workoutSessions, setLogs},
    ).get();
    return rows.map(_summaryFromRow).toList();
  }

  SessionSummary _summaryFromRow(QueryRow row) {
    final Map<String, Object?> data = row.data;
    final Object? finished = data['finished_at'];
    return SessionSummary(
      id: (data['id']! as num).toInt(),
      dayIndex: (data['day_index']! as num).toInt(),
      startedAt: _toDate((data['started_at']! as num).toInt()),
      finishedAt: finished == null ? null : _toDate((finished as num).toInt()),
      volumeKg: (data['volume'] as num?)?.toDouble() ?? 0,
      completedSets: (data['set_count'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime _toDate(int unixSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);

  /// Best estimated 1RM per session for a single exercise, oldest first.
  Future<List<ProgressPoint>> progressSeries(int exerciseId) async {
    final List<QueryRow> rows = await customSelect(
      'SELECT s.started_at AS started_at, '
      'MAX(l.weight_kg * (1.0 + l.reps / 30.0)) AS e1rm, '
      'MAX(l.weight_kg) AS top_weight, '
      'SUM(l.weight_kg * l.reps) AS volume '
      'FROM set_logs l JOIN workout_sessions s ON s.id = l.session_id '
      'WHERE l.exercise_id = ? AND l.completed = 1 AND l.reps > 0 '
      'GROUP BY l.session_id ORDER BY s.started_at ASC',
      variables: [Variable<int>(exerciseId)],
      readsFrom: {workoutSessions, setLogs},
    ).get();

    return rows.map((QueryRow row) {
      final Map<String, Object?> data = row.data;
      return ProgressPoint(
        date: _toDate((data['started_at']! as num).toInt()),
        estimatedOneRm: (data['e1rm'] as num?)?.toDouble() ?? 0,
        topWeightKg: (data['top_weight'] as num?)?.toDouble() ?? 0,
        volumeKg: (data['volume'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<void> clearHistory() async {
    await delete(setLogs).go();
    await delete(workoutSessions).go();
  }

  Future<void> resetEverything() async {
    await clearHistory();
    await delete(exercises).go();
    await seedIfEmpty();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'fitpulse.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
