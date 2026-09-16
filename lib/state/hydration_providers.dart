import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/hydration_repository.dart';
import '../domain/hydration.dart';
import 'current_day.dart';
import 'providers.dart';
import 'settings_controller.dart';

final Provider<HydrationRepository> hydrationRepositoryProvider =
    Provider<HydrationRepository>(
  (ref) => HydrationRepository(ref.watch(databaseProvider)),
);

/// Every drink logged today, oldest first.
///
/// Keyed on [currentDayProvider] for the same reason the food query is: the
/// Today screen never unmounts, so a window resolved once would stay pinned
/// to the day the app was opened.
final StreamProvider<List<WaterLog>> todayWaterLogsProvider =
    StreamProvider<List<WaterLog>>((ref) {
  final DateTime day = ref.watch(currentDayProvider);
  return ref.watch(hydrationRepositoryProvider).watchWaterLogsForDay(day);
});

/// Today's total, count, and the drink undo would remove.
final Provider<HydrationToday> todayHydrationProvider =
    Provider<HydrationToday>((ref) {
  return ref.watch(todayWaterLogsProvider).maybeWhen(
        data: (List<WaterLog> logs) =>
            ref.watch(hydrationRepositoryProvider).todayFrom(logs),
        orElse: () => HydrationToday.empty,
      );
});

/// How many days back the hydration trend covers. 7 or 30.
final StateProvider<int> hydrationRangeProvider =
    StateProvider<int>((ref) => 7);

/// Daily totals over the last [hydrationRangeProvider] days, ending today.
final StreamProvider<HydrationTrend> hydrationTrendProvider =
    StreamProvider<HydrationTrend>((ref) {
  final DateTime today = ref.watch(currentDayProvider);
  final int days = ref.watch(hydrationRangeProvider);
  final int goal =
      ref.watch(settingsProvider.select((AppSettings s) => s.waterGoalMl));
  final HydrationRepository repo = ref.watch(hydrationRepositoryProvider);

  final DateTime start =
      DateTime(today.year, today.month, today.day - (days - 1));
  final DateTime end = DateTime(today.year, today.month, today.day + 1);

  return repo.watchWaterLogsBetween(start, end).map(
        (List<WaterLog> logs) =>
            repo.trendFrom(logs, from: start, days: days, goalMl: goal),
      );
});
