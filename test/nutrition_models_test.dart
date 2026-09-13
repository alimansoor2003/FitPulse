import 'package:fitpulse/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealType', () {
    test('round-trips through the stored label', () {
      for (final MealType type in MealType.values) {
        expect(MealType.fromLabel(type.label), type);
      }
    });

    test('tolerates the casing a language model actually returns', () {
      expect(MealType.fromLabel('breakfast'), MealType.breakfast);
      expect(MealType.fromLabel('  DINNER '), MealType.dinner);
    });

    test('falls back to snack rather than throwing', () {
      expect(MealType.fromLabel('Brunch'), MealType.snack);
      expect(MealType.fromLabel(null), MealType.snack);
      expect(MealType.fromLabel(''), MealType.snack);
    });

    test('picks the meal that matches the clock', () {
      expect(MealType.forTime(DateTime(2026, 9, 13, 8)), MealType.breakfast);
      expect(MealType.forTime(DateTime(2026, 9, 13, 13)), MealType.lunch);
      expect(MealType.forTime(DateTime(2026, 9, 13, 19)), MealType.dinner);
      expect(MealType.forTime(DateTime(2026, 9, 13, 23)), MealType.snack);
    });
  });

  group('ParsedFood.fromJson', () {
    ParsedFood parse(Map<String, Object?> json) => ParsedFood.fromJson(
          json,
          localId: 7,
          fallbackMeal: MealType.lunch,
        );

    test('reads a well-formed item', () {
      final ParsedFood food = parse(<String, Object?>{
        'name': '  Grilled chicken  ',
        'mealType': 'Dinner',
        'calories': 320,
        'proteinG': 42.5,
        'carbsG': 0,
        'fatG': 12.1,
      });

      expect(food.localId, 7);
      expect(food.name, 'Grilled chicken');
      expect(food.mealType, MealType.dinner);
      expect(food.calories, 320);
      expect(food.proteinG, 42.5);
      expect(food.fatG, 12.1);
    });

    test('coerces numbers sent as strings', () {
      final ParsedFood food = parse(<String, Object?>{
        'name': 'Oats',
        'calories': '150',
        'proteinG': '5.5',
      });

      expect(food.calories, 150);
      expect(food.proteinG, 5.5);
    });

    test('a bad item costs one row, not the whole parse', () {
      final ParsedFood food = parse(<String, Object?>{
        'name': null,
        'mealType': 'Elevenses',
        'calories': null,
        'proteinG': 'not a number',
        'carbsG': -40,
        'fatG': double.nan,
      });

      expect(food.name, 'Unnamed item');
      expect(food.mealType, MealType.snack);
      expect(food.calories, 0);
      expect(food.proteinG, 0);
      expect(food.carbsG, 0, reason: 'negative macros are clamped away');
      expect(food.fatG, 0, reason: 'NaN must not reach the database');
    });

    test('uses the fallback meal only when none was given', () {
      expect(parse(<String, Object?>{'name': 'Rice'}).mealType, MealType.lunch);
    });

    test('caps absurd values so one bad row cannot wreck the day total', () {
      final ParsedFood food = parse(<String, Object?>{
        'name': 'Typo',
        'calories': 99999999,
        'proteinG': 1e9,
      });

      expect(food.calories, 100000);
      expect(food.proteinG, 10000);
    });
  });

  group('MacroTargets', () {
    test('ships sensible defaults', () {
      expect(MacroTargets.fallback.calories, 2000);
      expect(MacroTargets.fallback.proteinG, 150);
      expect(MacroTargets.fallback.carbsG, 200);
      expect(MacroTargets.fallback.fatG, 65);
    });
  });

  group('DailyMacros', () {
    test('an empty day is all zeroes', () {
      expect(DailyMacros.empty.calories, 0);
      expect(DailyMacros.empty.itemCount, 0);
    });
  });
}
