import 'package:fitpulse/domain/day_tracker.dart';
import 'package:fitpulse/domain/hydration.dart';
import 'package:fitpulse/domain/models.dart';
import 'package:fitpulse/domain/nutrition.dart';
import 'package:fitpulse/features/home/widgets/day_tracker_strip.dart';
import 'package:fitpulse/state/day_tracker_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime today = DateTime(2026, 9, 17);

  DailyNutrition protein(DateTime day, double g) => DailyNutrition(
        day: day,
        calories: 0,
        proteinG: g,
        carbsG: 0,
        fatG: 0,
        itemCount: 1,
      );

  DailyHydration water(DateTime day, int ml) =>
      DailyHydration(day: day, totalMl: ml, drinkCount: 1);

  SessionSummary session(DateTime startedAt, {bool finished = true}) =>
      SessionSummary(
        id: startedAt.millisecondsSinceEpoch,
        dayIndex: 0,
        startedAt: startedAt,
        finishedAt: finished ? startedAt.add(const Duration(hours: 1)) : null,
        volumeKg: 0,
        completedSets: 0,
      );

  List<DayMark> track({
    List<DailyNutrition> nutrition = const <DailyNutrition>[],
    List<DailyHydration> hydration = const <DailyHydration>[],
    List<SessionSummary> finished = const <SessionSummary>[],
    DateTime? on,
  }) =>
      buildDayTrack(
        today: on ?? today,
        nutrition: nutrition,
        hydration: hydration,
        finished: finished,
        proteinTargetG: 150,
        waterGoalMl: 2500,
      );

  group('fuelScore', () {
    test('averages protein and water, each capped at its target', () {
      expect(
        fuelScore(
            proteinG: 75, proteinTargetG: 150, waterMl: 2500, waterGoalMl: 2500),
        0.75,
      );
      expect(
        fuelScore(
            proteinG: 400, proteinTargetG: 150, waterMl: 0, waterGoalMl: 2500),
        0.5,
        reason: 'triple the protein does not make up for no water',
      );
    });

    test('uses only the targets that are set', () {
      expect(
        fuelScore(proteinG: 75, proteinTargetG: 0, waterMl: 0, waterGoalMl: 0),
        0,
      );
      expect(
        fuelScore(
            proteinG: 0, proteinTargetG: 0, waterMl: 1250, waterGoalMl: 2500),
        0.5,
      );
    });
  });

  group('buildDayTrack', () {
    test('three days back, today, three days ahead', () {
      final List<DayMark> marks = track();
      expect(marks.map((DayMark m) => m.day.day), <int>[14, 15, 16, 17, 18, 19, 20]);
      expect(marks.where((DayMark m) => m.isToday).single.day, today);
      expect(marks.where((DayMark m) => m.isFuture), hasLength(3));
    });

    test('crosses a month end on calendar days', () {
      final List<DayMark> marks = track(on: DateTime(2026, 10, 1, 21, 30));
      expect(
        marks.map((DayMark m) => m.day),
        <DateTime>[
          DateTime(2026, 9, 28),
          DateTime(2026, 9, 29),
          DateTime(2026, 9, 30),
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 4),
        ],
      );
    });

    test('fills each day from its own logs', () {
      final List<DayMark> marks = track(
        nutrition: <DailyNutrition>[
          protein(DateTime(2026, 9, 15), 150),
          protein(today, 75),
        ],
        hydration: <DailyHydration>[
          water(DateTime(2026, 9, 15), 3000),
          water(today, 1250),
        ],
      );
      expect(marks[1].fuel, 1);
      expect(marks[1].fuelDone, isTrue);
      expect(marks[2].fuel, 0, reason: 'nothing logged on the 16th');
      expect(marks[3].fuel, 0.5);
    });

    test('a finished session marks the day it started', () {
      final List<DayMark> marks = track(finished: <SessionSummary>[
        session(DateTime(2026, 9, 16, 23, 30)),
        session(today.add(const Duration(hours: 9)), finished: false),
      ]);
      expect(marks[2].workoutDone, isTrue,
          reason: 'a late session running past midnight belongs to the 16th');
      expect(marks[3].workout, 0, reason: 'an open session is not done yet');
    });

    test('future days never carry progress', () {
      final DateTime tomorrow = DateTime(2026, 9, 18);
      final List<DayMark> marks = track(
        nutrition: <DailyNutrition>[protein(tomorrow, 150)],
        hydration: <DailyHydration>[water(tomorrow, 2500)],
        finished: <SessionSummary>[session(tomorrow.add(const Duration(hours: 8)))],
      );
      expect(marks[4].fuel, 0);
      expect(marks[4].workout, 0);
    });
  });

  group('DayTrackerStrip', () {
    List<DayMark> sample() => <DayMark>[
          for (int i = -3; i <= 3; i++)
            DayMark(
              day: DateTime(2026, 9, 27 + i),
              fuel: i > 0 ? 0 : (i + 3) / 3,
              workout: i.isEven && i <= 0 ? 1 : 0,
              isToday: i == 0,
              isFuture: i > 0,
            ),
        ];

    Future<void> pump(WidgetTester tester, {required double width}) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            dayTrackProvider.overrideWith((Ref ref) => sample()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(1.15),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: DayTrackerStrip(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('seven days fit a small phone at large text', (
      WidgetTester tester,
    ) async {
      await pump(tester, width: 340);
      expect(tester.takeException(), isNull);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('Food & water'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
    });

    testWidgets('each day reads its rings aloud', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, width: 412);
      expect(
        find.bySemanticsLabel('Today, Sun 27: food and water done, workout done'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Thu 24: food and water 0 percent, no workout'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Mon 28'), findsOneWidget);
      handle.dispose();
    });
  });
}
