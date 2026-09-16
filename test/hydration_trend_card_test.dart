import 'package:fitpulse/domain/hydration.dart';
import 'package:fitpulse/features/hydration/widgets/hydration_trend_card.dart';
import 'package:fitpulse/state/hydration_providers.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  HydrationTrend trendOf(int days, {int everyNth = 2, int goalMl = 2500}) {
    final DateTime start = DateTime(2026, 9, 16 - (days - 1));
    final List<DailyHydration> rows = <DailyHydration>[];
    int logged = 0;
    int total = 0;
    int onGoal = 0;
    for (int i = 0; i < days; i++) {
      final bool has = i % everyNth == 0;
      final int ml = has ? 1800 + i * 90 : 0;
      if (has) {
        logged++;
        total += ml;
        if (ml >= goalMl) onGoal++;
      }
      rows.add(DailyHydration(
        day: DateTime(start.year, start.month, start.day + i),
        totalMl: ml,
        drinkCount: has ? 6 : 0,
      ));
    }
    return HydrationTrend(
      days: rows,
      averageMl: logged == 0 ? 0 : (total / logged).round(),
      daysLogged: logged,
      daysOnGoal: onGoal,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    HydrationTrend trend, {
    int range = 7,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{'onboarded': true});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          hydrationRangeProvider.overrideWith((Ref ref) => range),
          hydrationTrendProvider.overrideWith(
            (Ref ref) => Stream<HydrationTrend>.value(trend),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: const Size(420, 900),
                textScaler: TextScaler.linear(textScale),
              ),
              child:
                  const SingleChildScrollView(child: HydrationTrendCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a week reads average, logged days, and days on goal', (
    WidgetTester tester,
  ) async {
    final HydrationTrend trend = trendOf(7);
    await pump(tester, trend);

    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text(formatWaterMl(trend.averageMl)), findsOneWidget);
    expect(find.text('averaged over ${trend.daysLogged} days logged of 7'),
        findsOneWidget);
    expect(find.text('${trend.daysOnGoal} / ${trend.daysLogged}'),
        findsOneWidget);
    expect(find.text('2.5 L daily goal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a month of bars fits at handset width', (
    WidgetTester tester,
  ) async {
    await pump(tester, trendOf(30), range: 30);
    expect(find.textContaining('days logged of 30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives the largest text scale the app allows', (
    WidgetTester tester,
  ) async {
    await pump(tester, trendOf(30), range: 30, textScale: 1.15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty window explains itself', (WidgetTester tester) async {
    await pump(tester, HydrationTrend.empty);
    expect(find.textContaining('No water logged in the last 7 days'),
        findsOneWidget);
    expect(find.text('days on goal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
