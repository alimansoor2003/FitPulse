import '../data/db/app_database.dart';

/// Which meal an item belongs to. Persisted by [label] so the `food_logs`
/// table stays readable in a raw SQLite dump.
enum MealType {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const MealType(this.label);

  final String label;

  /// Tolerant lookup: the value comes back from a language model, so casing
  /// and stray whitespace are expected and anything unrecognised is treated
  /// as a snack rather than throwing.
  static MealType fromLabel(String? raw) {
    final String key = (raw ?? '').trim().toLowerCase();
    for (final MealType type in MealType.values) {
      if (type.label.toLowerCase() == key) return type;
    }
    return MealType.snack;
  }

  /// The meal most likely being eaten at [time]. Used as the pre-selection in
  /// the logger and as the fallback when the model omits a meal.
  static MealType forTime(DateTime time) {
    final int hour = time.hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 16) return MealType.lunch;
    if (hour < 22) return MealType.dinner;
    return MealType.snack;
  }
}

/// One food item on its way into the database.
///
/// [localId] only exists in memory: it keeps list keys and swipe-to-delete
/// stable while the user edits the review list, before any row exists.
class ParsedFood {
  const ParsedFood({
    required this.localId,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int localId;
  final String name;
  final MealType mealType;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  /// Reads one object out of the model's JSON array. Every field is treated
  /// as optional and coerced, because a malformed item should cost the user
  /// one bad row to fix - not the whole parse.
  factory ParsedFood.fromJson(
    Map<String, Object?> json, {
    required int localId,
    required MealType fallbackMeal,
  }) {
    final String name = json['name']?.toString().trim() ?? '';
    return ParsedFood(
      localId: localId,
      name: name.isEmpty ? 'Unnamed item' : name,
      mealType: json['mealType'] == null
          ? fallbackMeal
          : MealType.fromLabel(json['mealType']!.toString()),
      calories: _int(json['calories']),
      proteinG: _double(json['proteinG']),
      carbsG: _double(json['carbsG']),
      fatG: _double(json['fatG']),
    );
  }

  ParsedFood copyWith({
    String? name,
    MealType? mealType,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) {
    return ParsedFood(
      localId: localId,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }

  static int _int(Object? value) {
    if (value is num) return value.round().clamp(0, 100000);
    return (double.tryParse(value?.toString() ?? '') ?? 0)
        .round()
        .clamp(0, 100000);
  }

  static double _double(Object? value) {
    final double parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    if (parsed.isNaN || parsed.isNegative) return 0;
    return parsed > 10000 ? 10000 : parsed;
  }
}

/// Everything eaten on one day, rolled up for the summary card.
class DailyMacros {
  const DailyMacros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.itemCount,
  });

  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int itemCount;

  static const DailyMacros empty = DailyMacros(
    calories: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    itemCount: 0,
  );

  static DailyMacros from(List<FoodLog> logs) {
    int calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    for (final FoodLog log in logs) {
      calories += log.calories;
      protein += log.proteinG;
      carbs += log.carbsG;
      fat += log.fatG;
    }
    return DailyMacros(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      itemCount: logs.length,
    );
  }
}

/// The daily goals the summary card fills against, editable in Settings.
class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  static const MacroTargets fallback = MacroTargets(
    calories: 2000,
    proteinG: 150,
    carbsG: 200,
    fatG: 65,
  );
}
