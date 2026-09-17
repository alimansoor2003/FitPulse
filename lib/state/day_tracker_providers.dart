import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/hydration_repository.dart';
import '../data/repositories/nutrition_repository.dart';
import '../domain/day_tracker.dart';
import '../domain/hydration.dart';
import '../domain/nutrition.dart';
import 'hydration_providers.dart';
import 'nutrition_providers.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// Days from the first tracked past day through today.
const int _trackedDays = kTrackerPastDays + 1;

/// Protein per day over the tracked window. Its own query rather than the
/// Progress trend's, so switching that card between 7 and 30 days never
/// re-subscribes the strip.
final StreamProvider<List<DailyNutrition>> trackerNutritionProvider =
    StreamProvider<List<DailyNutrition>>((ref) {
  final DateTime today = ref.watch(currentDayProvider);
  final NutritionRepository repo = ref.watch(nutritionRepositoryProvider);
  final DateTime start =
      DateTime(today.year, today.month, today.day - kTrackerPastDays);
  final DateTime end = DateTime(today.year, today.month, today.day + 1);
  return repo.watchFoodLogsBetween(start, end).map(
        (List<FoodLog> logs) =>
            repo.trendFrom(logs, from: start, days: _trackedDays).days,
      );
});

/// Water per day over the tracked window.
final StreamProvider<List<DailyHydration>> trackerHydrationProvider =
    StreamProvider<List<DailyHydration>>((ref) {
  final DateTime today = ref.watch(currentDayProvider);
  final HydrationRepository repo = ref.watch(hydrationRepositoryProvider);
  final DateTime start =
      DateTime(today.year, today.month, today.day - kTrackerPastDays);
  final DateTime end = DateTime(today.year, today.month, today.day + 1);
  // The goal only feeds the trend's on-goal count, which the strip ignores,
  // so it is not watched here: changing it must not restart the query.
  return repo.watchWaterLogsBetween(start, end).map(
        (List<WaterLog> logs) => repo
            .trendFrom(logs, from: start, days: _trackedDays, goalMl: 0)
            .days,
      );
});

/// The strip's columns. Empty rings until the queries first emit, never a
/// loading state.
final Provider<List<DayMark>> dayTrackProvider =
    Provider<List<DayMark>>((ref) {
  final AppSettings settings = ref.watch(settingsProvider);
  return buildDayTrack(
    today: ref.watch(currentDayProvider),
    nutrition: ref.watch(trackerNutritionProvider).valueOrNull ??
        const <DailyNutrition>[],
    hydration: ref.watch(trackerHydrationProvider).valueOrNull ??
        const <DailyHydration>[],
    finished: ref.watch(finishedSessionsProvider),
    proteinTargetG: settings.macroTargets.proteinG,
    waterGoalMl: settings.waterGoalMl,
  );
});
