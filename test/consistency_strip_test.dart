import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/domain/models.dart';
import 'package:fitpulse/domain/nutrition.dart';
import 'package:fitpulse/features/history/history_screen.dart';
import 'package:fitpulse/state/nutrition_providers.dart';
import 'package:fitpulse/state/providers.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the "BOTTOM OVERFLOWED BY 12 PIXELS" banner on the
/// Progress screen's Weekly Consistency strip.
///
/// Each bar column stacks a session count, the bar itself, and a week-start
/// date inside a fixed-height box. The bar grows with the week's session
/// ratio and tops out once a week meets the weekly goal - and at that point
/// the stack was taller than the box reserved for it, so the date label got
/// pushed past the bottom edge and clipped.
///
/// It never showed up before because it needs a week that actually hits the
/// goal; every other week in the sample data has zero sessions.
void main() {
  /// Eight weeks where exactly one meets the goal - the shape that overflows.
  List<WeeklyLoad> weeksWithAMaxedBar() {
    final DateTime start = DateTime(2026, 7, 20);
    return <WeeklyLoad>[
      for (int i = 0; i < 8; i++)
        WeeklyLoad(
          weekStart: start.add(Duration(days: 7 * i)),
          // Week 7 doubles the goal, so its ratio clamps to 1.0 and its bar
          // reaches maximum height.
          sessions: i == 6 ? 6 : (i == 7 ? 1 : 0),
          volumeKg: i == 6 ? 12100 : 0,
        ),
    ];
  }

  Future<void> pumpProgress(
    WidgetTester tester, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // Everything the screen reads, stubbed - so the layout is exercised
          // without opening SQLite.
          finishedSessionsProvider
              .overrideWithValue(const <SessionSummary>[]),
          weeklyLoadProvider.overrideWithValue(weeksWithAMaxedBar()),
          dashboardStatsProvider.overrideWithValue(
            const DashboardStats(
              sessionsThisWeek: 6,
              weeklyGoal: 3,
              volumeThisWeekKg: 12100,
              totalSessions: 7,
              totalVolumeKg: 12100,
              streakWeeks: 2,
              completedSets: 28,
            ),
          ),
          allExercisesProvider.overrideWith((Ref ref) async => <Exercise>[]),
          // The screen also carries the nutrition trend card now; stub it so
          // this stays a layout test and never reaches SQLite.
          sharedPreferencesProvider.overrideWithValue(prefs),
          nutritionTrendProvider.overrideWith(
            (Ref ref) => Stream<NutritionTrend>.value(NutritionTrend.empty),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: const HistoryScreen(),
            ),
          ),
        ),
      ),
    );
    // FadeIn staggers with Future.delayed, which schedules no frame of its
    // own, so pump past the longest delay before settling.
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('a week that meets the goal does not overflow the strip', (
    WidgetTester tester,
  ) async {
    await pumpProgress(tester);

    expect(find.text('Weekly Consistency'), findsOneWidget);
    expect(find.text('6'), findsOneWidget, reason: 'the maxed week is drawn');
    expect(
      tester.takeException(),
      isNull,
      reason: 'the tallest bar must fit inside the strip',
    );
  });

  testWidgets('it still fits at the largest text scale the app allows', (
    WidgetTester tester,
  ) async {
    // app.dart clamps the device font scale to 0.9-1.15, so 1.15 is the
    // worst case a real user can produce.
    await pumpProgress(tester, textScale: 1.15);

    expect(
      tester.takeException(),
      isNull,
      reason: 'larger labels must eat into the bar, not overflow the box',
    );
  });
}
