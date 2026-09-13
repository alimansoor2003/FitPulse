import 'package:drift/drift.dart';

/// One exercise slot inside a training day. Seeded on first launch, but the
/// schema is deliberately editable (order/sets/rest) so a routine editor can
/// be layered on later without a migration.
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 1 = Chest & Triceps, 2 = Back & Biceps, 3 = Legs & Shoulders.
  IntColumn get dayIndex => integer()();
  TextColumn get nameEn => text().withLength(min: 1, max: 80)();
  TextColumn get nameAr => text().withLength(min: 1, max: 80)();

  /// Human label for the prescribed volume, e.g. "2-3 sets".
  TextColumn get targetLabel => text().withDefault(const Constant('3 sets'))();
  IntColumn get defaultSets => integer().withDefault(const Constant(3))();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
  IntColumn get orderIndex => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// A single training session (one calendar workout).
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayIndex => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// One logged set: weight x reps, plus whether it was actually completed.
class SetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer()
      .references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();

  /// 1-based position of the set within the exercise.
  IntColumn get setIndex => integer()();
  RealColumn get weightKg => real().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// One food item eaten at a point in time.
///
/// Rows land here either from the AI parser (which turns a sentence into a
/// list of items) or from the manual entry form - the table itself does not
/// record which, because an item is an item once it has been reviewed.
class FoodLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Breakfast / Lunch / Dinner / Snack, stored as text so the column stays
  /// readable in a raw SQLite dump. Parsed back through `MealType.fromLabel`,
  /// which falls back to Snack for anything unrecognised.
  TextColumn get mealType => text().withLength(min: 1, max: 16)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get calories => integer().withDefault(const Constant(0))();
  RealColumn get proteinG => real().withDefault(const Constant(0))();
  RealColumn get carbsG => real().withDefault(const Constant(0))();
  RealColumn get fatG => real().withDefault(const Constant(0))();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
}
