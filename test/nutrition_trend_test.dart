import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/data/repositories/nutrition_repository.dart';
import 'package:fitpulse/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

/// The trend roll-up is pure, so the part that actually goes wrong - which
/// calendar day a row lands on, and what the average is divided by - is
/// tested without a database.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late NutritionRepository repo;

  setUp(() {
    repo = NutritionRepository(
      AppDatabase.withExecutor(NativeDatabase.memory()),
    );
  });

  FoodLog log(
    DateTime at, {
    int calories = 100,
    double protein = 10,
    double carbs = 20,
    double fat = 5,
  }) {
    return FoodLog(
      id: at.millisecondsSinceEpoch % 100000,
      mealType: 'Snack',
      name: 'Item',
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      loggedAt: at,
    );
  }

  group('trendFrom', () {
    test('gives one row per day in the window, oldest first', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[],
        from: DateTime(2026, 9, 8),
        days: 7,
      );

      expect(trend.days, hasLength(7));
      expect(trend.days.first.day, DateTime(2026, 9, 8));
      expect(trend.days.last.day, DateTime(2026, 9, 14));
    });

    test('sums every log onto its own calendar day', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[
          log(DateTime(2026, 9, 12, 8, 30), calories: 300),
          log(DateTime(2026, 9, 12, 19, 5), calories: 500),
          log(DateTime(2026, 9, 14, 0, 15), calories: 260),
        ],
        from: DateTime(2026, 9, 8),
        days: 7,
      );

      final Map<DateTime, int> byDay = <DateTime, int>{
        for (final DailyNutrition d in trend.days) d.day: d.calories,
      };
      expect(byDay[DateTime(2026, 9, 12)], 800);
      expect(byDay[DateTime(2026, 9, 14)], 260);
      expect(byDay[DateTime(2026, 9, 13)], 0);
    });

    test('a minute past midnight belongs to the new day', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[
          log(DateTime(2026, 9, 13, 23, 59), calories: 400),
          log(DateTime(2026, 9, 14, 0, 1), calories: 700),
        ],
        from: DateTime(2026, 9, 13),
        days: 2,
      );

      expect(trend.days.first.calories, 400);
      expect(trend.days.last.calories, 700);
    });

    test('averages over days logged, not over the whole window', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[
          log(DateTime(2026, 9, 12, 9), calories: 1000, protein: 50),
          log(DateTime(2026, 9, 14, 9), calories: 2000, protein: 100),
        ],
        from: DateTime(2026, 9, 8),
        days: 7,
      );

      expect(trend.daysLogged, 2);
      // 3000 over the two logged days, not over all seven.
      expect(trend.average.calories, 1500);
      expect(trend.average.proteinG, 75);
    });

    test('an empty window reports no average rather than zero intake', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[],
        from: DateTime(2026, 9, 8),
        days: 7,
      );

      expect(trend.isEmpty, isTrue);
      expect(trend.daysLogged, 0);
      expect(trend.average.calories, 0);
      expect(trend.days, hasLength(7), reason: 'the gap is still drawn');
    });

    test('unlogged days stay distinguishable from zero-calorie days', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[log(DateTime(2026, 9, 14, 9), calories: 0)],
        from: DateTime(2026, 9, 13),
        days: 2,
      );

      expect(trend.days.first.isLogged, isFalse);
      expect(trend.days.last.isLogged, isTrue,
          reason: 'a logged item with no calories is still a logged day');
      expect(trend.daysLogged, 1);
    });

    test('steps across a month boundary by calendar day', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[log(DateTime(2026, 10, 1, 12), calories: 900)],
        from: DateTime(2026, 9, 29),
        days: 4,
      );

      expect(
        trend.days.map((DailyNutrition d) => d.day).toList(),
        <DateTime>[
          DateTime(2026, 9, 29),
          DateTime(2026, 9, 30),
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
        ],
      );
      expect(trend.days[2].calories, 900);
    });

    test('peak calories scales to the busiest day', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[
          log(DateTime(2026, 9, 12, 9), calories: 1200),
          log(DateTime(2026, 9, 13, 9), calories: 2400),
        ],
        from: DateTime(2026, 9, 8),
        days: 7,
      );

      expect(trend.peakCalories, 2400);
    });

    test('a 30 day window is a month of rows', () {
      final NutritionTrend trend = repo.trendFrom(
        <FoodLog>[],
        from: DateTime(2026, 8, 16),
        days: 30,
      );

      expect(trend.days, hasLength(30));
      expect(trend.days.last.day, DateTime(2026, 9, 14));
    });
  });
}
