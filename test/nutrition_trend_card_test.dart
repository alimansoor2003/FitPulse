import 'package:fitpulse/domain/nutrition.dart';
import 'package:fitpulse/features/nutrition/widgets/nutrition_trend_card.dart';
import 'package:fitpulse/state/nutrition_providers.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The trend card has to survive both ranges at real handset width - 30 bars
/// is the case where labels and bar widths get tight.
void main() {
  NutritionTrend trendOf(int days, {int loggedEvery = 3}) {
    final DateTime start = DateTime(2026, 9, 14 - (days - 1));
    int loggedDays = 0;
    int calories = 0;
    final List<DailyNutrition> rows = <DailyNutrition>[];
    for (int i = 0; i < days; i++) {
      final bool logged = i % loggedEvery == 0;
      if (logged) {
        loggedDays++;
        calories += 1800 + i * 10;
      }
      rows.add(
        DailyNutrition(
          day: DateTime(start.year, start.month, start.day + i),
          calories: logged ? 1800 + i * 10 : 0,
          proteinG: logged ? 120 : 0,
          carbsG: logged ? 180 : 0,
          fatG: logged ? 55 : 0,
          itemCount: logged ? 3 : 0,
        ),
      );
    }
    return NutritionTrend(
      days: rows,
      average: DailyMacros(
        calories: loggedDays == 0 ? 0 : (calories / loggedDays).round(),
        proteinG: 120,
        carbsG: 180,
        fatG: 55,
        itemCount: loggedDays,
      ),
      daysLogged: loggedDays,
    );
  }

  Future<void> pumpCard(WidgetTester tester, NutritionTrend trend,
      {int range = 7}) async {
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
          nutritionRangeProvider.overrideWith((Ref ref) => range),
          nutritionTrendProvider
              .overrideWith((Ref ref) => Stream<NutritionTrend>.value(trend)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NutritionTrendCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a week of daily calories', (WidgetTester tester) async {
    await pumpCard(tester, trendOf(7));

    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.textContaining('kcal / day'), findsOneWidget);
    expect(find.textContaining('days logged of 7'), findsOneWidget);
    expect(find.text('2000 kcal target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a month without overflowing', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, trendOf(30), range: 30);

    expect(find.textContaining('days logged of 30'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: '30 bars must still fit the card at handset width',
    );
  });

  testWidgets('an empty window explains itself instead of showing zeroes', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, NutritionTrend.empty);

    expect(find.textContaining('Nothing logged in the last 7 days'),
        findsOneWidget);
    expect(find.textContaining('kcal / day'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives the largest text scale the app allows', (
    WidgetTester tester,
  ) async {
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
          nutritionRangeProvider.overrideWith((Ref ref) => 30),
          nutritionTrendProvider.overrideWith(
            (Ref ref) => Stream<NutritionTrend>.value(trendOf(30)),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.15)),
              child: const SingleChildScrollView(child: NutritionTrendCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
