/// The pinned quick-add slots on the hydration card, in order.
///
/// The labels are fixed; the amounts are the user's. Holding a slot for
/// [kPresetHoldDuration] lets them change what it logs.
const List<String> kWaterPresetLabels = <String>['Glass', 'Bottle'];
const List<int> kDefaultWaterPresetsMl = <int>[250, 500];

/// How long a preset has to be held before it opens for editing.
const Duration kPresetHoldDuration = Duration(milliseconds: 2500);

/// Bounds for a single custom drink. The upper bound catches a slipped extra
/// zero ("5000") rather than limiting a genuinely large bottle.
const int kMinDrinkMl = 10;
const int kMaxDrinkMl = 3000;

/// Rebuilds the pinned preset amounts from what SharedPreferences holds.
///
/// Anything unusable falls back slot by slot rather than wholesale: a missing
/// list, a list of the wrong length, a value that is not a number, or one
/// outside what a single drink can be. One bad slot should not reset the
/// other one the user deliberately set.
List<int> waterPresetsFrom(List<String>? saved) {
  return <int>[
    for (int i = 0; i < kDefaultWaterPresetsMl.length; i++)
      _presetAt(saved, i) ?? kDefaultWaterPresetsMl[i],
  ];
}

int? _presetAt(List<String>? saved, int index) {
  if (saved == null || index >= saved.length) return null;
  final int? ml = int.tryParse(saved[index].trim());
  if (ml == null || ml < kMinDrinkMl || ml > kMaxDrinkMl) return null;
  return ml;
}

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
