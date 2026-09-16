import '../../domain/hydration.dart';
import '../db/app_database.dart';

/// Application-facing API over the `water_logs` table, mirroring
/// [NutritionRepository]: screens and providers talk to this, never to Drift.
class HydrationRepository {
  HydrationRepository(this.db);

  final AppDatabase db;

  /// Day-keyed rather than "today", so a long-lived subscriber can be
  /// re-subscribed when the date changes. See `currentDayProvider`.
  Stream<List<WaterLog>> watchWaterLogsForDay(DateTime day) {
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = DateTime(day.year, day.month, day.day + 1);
    return db.watchWaterLogsBetween(start, end);
  }

  Stream<List<WaterLog>> watchWaterLogsBetween(DateTime start, DateTime end) =>
      db.watchWaterLogsBetween(start, end);

  /// Records a drink. Out-of-range amounts are clamped rather than rejected
  /// here; the custom-amount sheet is where the user is told why.
  Future<void> logDrink(int amountMl) {
    return db.insertWaterLog(amountMl.clamp(kMinDrinkMl, kMaxDrinkMl));
  }

  Future<void> deleteWaterLog(int id) => db.deleteWaterLog(id);

  Future<void> clearWaterLogs() => db.clearWaterLogs();

  /// Today's total, count, and the drink undo would remove.
  HydrationToday todayFrom(List<WaterLog> logs) {
    if (logs.isEmpty) return HydrationToday.empty;

    int total = 0;
    WaterLog latest = logs.first;
    for (final WaterLog log in logs) {
      total += log.amountMl;
      // Latest by time, then by id for drinks written in the same instant.
      final int byTime = log.loggedAt.compareTo(latest.loggedAt);
      if (byTime > 0 || (byTime == 0 && log.id > latest.id)) latest = log;
    }

    return HydrationToday(
      totalMl: total,
      drinkCount: logs.length,
      lastDrinkId: latest.id,
      lastDrinkMl: latest.amountMl,
    );
  }

  /// Buckets [logs] into one row per calendar day from [from] for [days]
  /// days. Pure, so the day boundaries are testable without a database.
  HydrationTrend trendFrom(
    List<WaterLog> logs, {
    required DateTime from,
    required int days,
    required int goalMl,
  }) {
    if (days <= 0) return HydrationTrend.empty;

    final DateTime start = DateTime(from.year, from.month, from.day);
    final Map<DateTime, (int, int)> byDay = <DateTime, (int, int)>{};
    for (final WaterLog log in logs) {
      final DateTime day = DateTime(
        log.loggedAt.year,
        log.loggedAt.month,
        log.loggedAt.day,
      );
      final (int ml, int count) = byDay[day] ?? (0, 0);
      byDay[day] = (ml + log.amountMl, count + 1);
    }

    final List<DailyHydration> rows = <DailyHydration>[];
    int loggedDays = 0;
    int onGoal = 0;
    int total = 0;

    for (int i = 0; i < days; i++) {
      // Step on calendar fields, not a 24h Duration, so a DST change cannot
      // land two rows on the same day.
      final DateTime day = DateTime(start.year, start.month, start.day + i);
      final (int ml, int count) = byDay[day] ?? (0, 0);
      rows.add(DailyHydration(day: day, totalMl: ml, drinkCount: count));

      if (count > 0) {
        loggedDays++;
        total += ml;
        if (goalMl > 0 && ml >= goalMl) onGoal++;
      }
    }

    return HydrationTrend(
      days: rows,
      averageMl: loggedDays == 0 ? 0 : (total / loggedDays).round(),
      daysLogged: loggedDays,
      daysOnGoal: onGoal,
    );
  }
}
