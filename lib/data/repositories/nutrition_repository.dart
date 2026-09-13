import 'package:drift/drift.dart' show Value;

import '../../domain/nutrition.dart';
import '../db/app_database.dart';

/// Application-facing API over the `food_logs` table, mirroring
/// [WorkoutRepository]: screens and providers talk to this, never to Drift.
class NutritionRepository {
  NutritionRepository(this.db);

  final AppDatabase db;

  Stream<List<FoodLog>> watchTodayFoodLogs() => db.watchTodayFoodLogs();

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

  Future<void> deleteFoodLog(int id) => db.deleteFoodLog(id);

  Future<void> clearFoodLogs() => db.clearFoodLogs();

  /// Pure roll-up, kept here so the summary card stays a dumb renderer.
  DailyMacros macrosFrom(List<FoodLog> logs) => DailyMacros.from(logs);
}
