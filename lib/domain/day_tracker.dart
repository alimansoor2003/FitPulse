import 'hydration.dart';
import 'models.dart';
import 'nutrition.dart';

/// Days shown before today in the tracker strip.
const int kTrackerPastDays = 3;

/// Days shown after today. They carry no progress, only the date.
const int kTrackerFutureDays = 3;

/// One column of the tracker strip.
class DayMark {
  const DayMark({
    required this.day,
    required this.fuel,
    required this.workout,
    required this.isToday,
    required this.isFuture,
  });

  /// Local midnight of the day this covers.
  final DateTime day;

  /// Food and water ring, 0..1: protein against its target and water against
  /// its goal, each capped at 1 and averaged. Overshooting one never makes up
  /// for skipping the other.
  final double fuel;

  /// Workout ring: 1 when a session was finished that day, otherwise 0.
  final double workout;

  final bool isToday;
  final bool isFuture;

  bool get fuelDone => fuel >= 1;
  bool get workoutDone => workout >= 1;
}

/// Protein and water progress for one day, averaged over whichever targets
/// are set. With no targets at all there is nothing to fill.
double fuelScore({
  required double proteinG,
  required double proteinTargetG,
  required int waterMl,
  required int waterGoalMl,
}) {
  final List<double> parts = <double>[
    if (proteinTargetG > 0) (proteinG / proteinTargetG).clamp(0.0, 1.0),
    if (waterGoalMl > 0) (waterMl / waterGoalMl).clamp(0.0, 1.0),
  ];
  if (parts.isEmpty) return 0;
  return parts.reduce((double a, double b) => a + b) / parts.length;
}

/// The strip's columns: [kTrackerPastDays] before [today], today, then
/// [kTrackerFutureDays] after it.
///
/// Pure, so the day matching is testable without a database. [nutrition] and
/// [hydration] may cover any span; days missing from them count as nothing
/// logged. A session belongs to the day it was started on, so a workout that
/// runs past midnight still marks the evening it began.
List<DayMark> buildDayTrack({
  required DateTime today,
  required List<DailyNutrition> nutrition,
  required List<DailyHydration> hydration,
  required List<SessionSummary> finished,
  required double proteinTargetG,
  required int waterGoalMl,
}) {
  final DateTime todayStart = DateTime(today.year, today.month, today.day);

  final Map<DateTime, double> protein = <DateTime, double>{
    for (final DailyNutrition d in nutrition) _dayOf(d.day): d.proteinG,
  };
  final Map<DateTime, int> water = <DateTime, int>{
    for (final DailyHydration d in hydration) _dayOf(d.day): d.totalMl,
  };
  final Set<DateTime> trained = <DateTime>{
    for (final SessionSummary s in finished)
      if (s.finishedAt != null) _dayOf(s.startedAt),
  };

  return <DayMark>[
    for (int i = -kTrackerPastDays; i <= kTrackerFutureDays; i++)
      _mark(
        // Calendar fields, not a 24h Duration, so a DST change cannot put two
        // columns on the same date.
        DateTime(todayStart.year, todayStart.month, todayStart.day + i),
        offset: i,
        protein: protein,
        water: water,
        trained: trained,
        proteinTargetG: proteinTargetG,
        waterGoalMl: waterGoalMl,
      ),
  ];
}

DayMark _mark(
  DateTime day, {
  required int offset,
  required Map<DateTime, double> protein,
  required Map<DateTime, int> water,
  required Set<DateTime> trained,
  required double proteinTargetG,
  required int waterGoalMl,
}) {
  final bool future = offset > 0;
  return DayMark(
    day: day,
    fuel: future
        ? 0
        : fuelScore(
            proteinG: protein[day] ?? 0,
            proteinTargetG: proteinTargetG,
            waterMl: water[day] ?? 0,
            waterGoalMl: waterGoalMl,
          ),
    workout: !future && trained.contains(day) ? 1 : 0,
    isToday: offset == 0,
    isFuture: future,
  );
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
