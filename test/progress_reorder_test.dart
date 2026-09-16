import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/domain/hydration.dart';
import 'package:fitpulse/domain/models.dart';
import 'package:fitpulse/domain/nutrition.dart';
import 'package:fitpulse/domain/progress_layout.dart';
import 'package:fitpulse/features/history/history_screen.dart';
import 'package:fitpulse/state/hydration_providers.dart';
import 'package:fitpulse/state/nutrition_providers.dart';
import 'package:fitpulse/state/progress_layout.dart';
import 'package:fitpulse/state/providers.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the real Progress screen: enter edit mode, drag a section, leave
/// edit mode, and check both the rendered order and what hit disk.
void main() {
  late ProviderContainer container;

  // GlassCard renders its InkWell in a Positioned.fill above the content, so
  // a tap aimed at an icon lands on that overlay rather than on the Icon's
  // own render box. The gesture still arrives; only the warning is spurious.

  Future<void> pumpProgress(
    WidgetTester tester, {
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarded': true,
      ...prefs,
    });
    final SharedPreferences instance = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(instance),
        finishedSessionsProvider.overrideWithValue(const <SessionSummary>[]),
        weeklyLoadProvider.overrideWithValue(const <WeeklyLoad>[]),
        dashboardStatsProvider.overrideWithValue(DashboardStats.empty),
        allExercisesProvider.overrideWith((Ref ref) async => <Exercise>[]),
        nutritionTrendProvider.overrideWith(
          (Ref ref) => Stream<NutritionTrend>.value(NutritionTrend.empty),
        ),
        hydrationTrendProvider.overrideWith(
          (Ref ref) => Stream<HydrationTrend>.value(HydrationTrend.empty),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  /// Section titles in the order they are laid out down the screen.
  List<String> renderedOrder(WidgetTester tester) {
    final List<(double, String)> found = <(double, String)>[];
    for (final ProgressSection section in ProgressSection.values) {
      final Finder f = find.text(section.title);
      if (f.evaluate().isEmpty) continue;
      found.add((tester.getTopLeft(f.first).dy, section.title));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return <String>[for (final (double _, String title) in found) title];
  }

  testWidgets('sections render in the saved order', (
    WidgetTester tester,
  ) async {
    await pumpProgress(
      tester,
      prefs: <String, Object>{
        'progress_section_order': <String>[
          'macro_overview',
          'weekly_consistency',
          'volume_trend',
          'hydration_trend',
          'one_rm_chart',
          'exercise_history',
        ],
      },
    );

    expect(renderedOrder(tester).first, 'Nutrition Trends');
  });

  testWidgets('edit mode swaps the cards for draggable rows', (
    WidgetTester tester,
  ) async {
    await pumpProgress(tester);

    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNothing,
        reason: 'nothing is draggable until edit mode is on');

    await tester.tap(find.byIcon(Icons.swap_vert_rounded),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.drag_indicator_rounded),
      findsNWidgets(ProgressSection.values.length),
    );
    expect(find.text('Drag the sections into the order you want.'),
        findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
  });

  testWidgets('dragging a section reorders it and persists the move', (
    WidgetTester tester,
  ) async {
    await pumpProgress(tester);
    expect(container.read(progressLayoutProvider), kDefaultProgressOrder);

    await tester.tap(find.byIcon(Icons.swap_vert_rounded),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Drag the first section's handle down past its neighbour.
    final Finder handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    final List<ProgressSection> order =
        container.read(progressLayoutProvider);
    expect(
      order.first,
      kDefaultProgressOrder[1],
      reason: 'the dragged section left the top slot',
    );
    expect(order.toSet(), ProgressSection.values.toSet());

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('progress_section_order'),
      <String>[for (final ProgressSection s in order) s.storageKey],
      reason: 'the drop is written straight away, not on exiting edit mode',
    );

    // Leaving edit mode renders the real cards in the new order.
    await tester.tap(find.byIcon(Icons.check_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing,
        reason: 'edit mode actually closed');
    expect(renderedOrder(tester).first, order.first.title);
  });

  testWidgets('reset is offered only once the layout is customised', (
    WidgetTester tester,
  ) async {
    await pumpProgress(tester);

    await tester.tap(find.byIcon(Icons.swap_vert_rounded),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Reset to default order'), findsNothing);

    await container.read(progressLayoutProvider.notifier).reorder(4, 0);
    await tester.pumpAndSettle();
    expect(find.text('Reset to default order'), findsOneWidget);

    await tester.tap(find.text('Reset to default order'),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(container.read(progressLayoutProvider), kDefaultProgressOrder);
    expect(find.text('Reset to default order'), findsNothing);
  });
}
