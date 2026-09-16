/// A one-tap amount on the hydration card.
class WaterPreset {
  const WaterPreset({required this.amountMl, required this.label});

  final int amountMl;
  final String label;
}

/// The quick-add buttons, smallest first.
const List<WaterPreset> kWaterPresets = <WaterPreset>[
  WaterPreset(amountMl: 250, label: 'Glass'),
  WaterPreset(amountMl: 500, label: 'Bottle'),
];

/// Bounds for a single custom drink. The upper bound catches a slipped extra
/// zero ("5000") rather than limiting a genuinely large bottle.
const int kMinDrinkMl = 10;
const int kMaxDrinkMl = 3000;

/// Formats a volume for display: "750 ml" below a litre, "1.25 L" above.
String formatWaterMl(int ml) {
  if (ml < 1000) return '$ml ml';
  final String litres = (ml / 1000).toStringAsFixed(2);
  // Trim trailing zeros: 1.50 -> 1.5, 2.00 -> 2.
  final String trimmed = litres.contains('.')
      ? litres.replaceFirst(RegExp(r'\.?0+$'), '')
      : litres;
  return '$trimmed L';
}

/// Today at a glance, rolled up from its drinks.
class HydrationToday {
  const HydrationToday({
    required this.totalMl,
    required this.drinkCount,
    this.lastDrinkId,
    this.lastDrinkMl,
  });

  final int totalMl;
  final int drinkCount;

  /// The most recent drink, which is what undo removes.
  final int? lastDrinkId;
  final int? lastDrinkMl;

  bool get canUndo => lastDrinkId != null;

  double progressToward(int goalMl) =>
      goalMl <= 0 ? 0 : (totalMl / goalMl).clamp(0.0, 1.0);

  static const HydrationToday empty =
      HydrationToday(totalMl: 0, drinkCount: 0);
}

/// One calendar day's total.
class DailyHydration {
  const DailyHydration({
    required this.day,
    required this.totalMl,
    required this.drinkCount,
  });

  /// Local midnight of the day this covers.
  final DateTime day;
  final int totalMl;
  final int drinkCount;

  bool get isLogged => drinkCount > 0;
}

/// A window of days and what is worth reading off it.
class HydrationTrend {
  const HydrationTrend({
    required this.days,
    required this.averageMl,
    required this.daysLogged,
    required this.daysOnGoal,
  });

  /// One entry per calendar day, oldest first, gaps included.
  final List<DailyHydration> days;

  /// Averaged over days with at least one drink, for the same reason the
  /// nutrition trend is: a forgotten day is missing data, not a day spent
  /// drinking nothing.
  final int averageMl;

  final int daysLogged;

  /// Days that reached the goal in effect when the trend was built.
  final int daysOnGoal;

  int get dayCount => days.length;

  bool get isEmpty => daysLogged == 0;

  int get peakMl => days.fold<int>(
        0,
        (int best, DailyHydration d) => d.totalMl > best ? d.totalMl : best,
      );

  static const HydrationTrend empty = HydrationTrend(
    days: <DailyHydration>[],
    averageMl: 0,
    daysLogged: 0,
    daysOnGoal: 0,
  );
}
