import 'package:drift/drift.dart' show Value;

import '../../domain/nutrition.dart';
import '../db/app_database.dart';

/// Application-facing API over the `food_logs` table, mirroring
/// [WorkoutRepository]: screens and providers talk to this, never to Drift.
class NutritionRepository {
  NutritionRepository(this.db);

  final AppDatabase db;

  /// Deliberately day-keyed rather than a "today" helper: a stream resolves
  /// its window once, so a long-lived subscriber has to be handed the day and
  /// re-subscribed when it changes. See `currentDayProvider`.
  Stream<List<FoodLog>> watchFoodLogsForDay(DateTime day) =>
      db.watchFoodLogsForDay(day);

  /// Writes a reviewed meal. [loggedAt] is stamped once for the whole batch so
  /// the items keep the order they were reviewed in rather than being
  /// separated by however long the insert took.
  Future<void> logMeal(List<ParsedFood> items, {DateTime? loggedAt}) {
    final DateTime stamp = loggedAt ?? DateTime.now();
    return db.insertFoodLogs(<FoodLogsCompanion>[
      for (int i = 0; i < items.length; i++)
        FoodLogsCompanion.insert(
          mealType: items[i].mealType.label,
          name: items[i].name,
          calories: Value<int>(items[i].calories),
          proteinG: Value<double>(items[i].proteinG),
          carbsG: Value<double>(items[i].carbsG),
          fatG: Value<double>(items[i].fatG),
          // Milliseconds apart, purely to keep a stable insertion order.
          loggedAt: Value<DateTime>(stamp.add(Duration(milliseconds: i))),
        ),
    ]);
  }

  Stream<List<FoodLog>> watchFoodLogsBetween(DateTime start, DateTime end) =>
      db.watchFoodLogsBetween(start, end);

  /// Buckets [logs] into one row per calendar day, starting at [from] and
  /// running for [days] days.
  ///
  /// Pure, so the bucketing - which is where the off-by-one and timezone
  /// mistakes live - is testable without a database. Days with nothing logged
  /// come back as zero rows so a gap stays visible in the chart.
  NutritionTrend trendFrom(
    List<FoodLog> logs, {
    required DateTime from,
    required int days,
  }) {
    if (days <= 0) return NutritionTrend.empty;

    final DateTime start = DateTime(from.year, from.month, from.day);
    final Map<DateTime, List<FoodLog>> byDay = <DateTime, List<FoodLog>>{};
    for (final FoodLog log in logs) {
      final DateTime day = DateTime(
        log.loggedAt.year,
        log.loggedAt.month,
        log.loggedAt.day,
      );
      byDay.putIfAbsent(day, () => <FoodLog>[]).add(log);
    }

    final List<DailyNutrition> rows = <DailyNutrition>[];
    int loggedDays = 0;
    int calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (int i = 0; i < days; i++) {
      // Adding to the date fields rather than adding a Duration keeps the
      // step on calendar days: a 24-hour Duration lands on the wrong day
      // across a daylight-saving change.
      final DateTime day = DateTime(start.year, start.month, start.day + i);
      final List<FoodLog> forDay = byDay[day] ?? const <FoodLog>[];
      final DailyMacros totals = DailyMacros.from(forDay);

      rows.add(
        DailyNutrition(
          day: day,
          calories: totals.calories,
          proteinG: totals.proteinG,
          carbsG: totals.carbsG,
          fatG: totals.fatG,
          itemCount: totals.itemCount,
        ),
      );

      if (totals.itemCount > 0) {
        loggedDays++;
        calories += totals.calories;
        protein += totals.proteinG;
        carbs += totals.carbsG;
        fat += totals.fatG;
      }
    }

    if (loggedDays == 0) {
      return NutritionTrend(
        days: rows,
        average: DailyMacros.empty,
        daysLogged: 0,
      );
    }

    return NutritionTrend(
      days: rows,
      average: DailyMacros(
        calories: (calories / loggedDays).round(),
        proteinG: protein / loggedDays,
        carbsG: carbs / loggedDays,
        fatG: fat / loggedDays,
        itemCount: loggedDays,
      ),
      daysLogged: loggedDays,
    );
  }

  Future<void> deleteFoodLog(int id) => db.deleteFoodLog(id);

  Future<void> clearFoodLogs() => db.clearFoodLogs();

  /// Pure roll-up, kept here so the summary card stays a dumb renderer.
  DailyMacros macrosFrom(List<FoodLog> logs) => DailyMacros.from(logs);
}
