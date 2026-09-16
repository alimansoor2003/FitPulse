import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/data/repositories/hydration_repository.dart';
import 'package:fitpulse/features/hydration/custom_water_sheet.dart';
import 'package:fitpulse/features/hydration/widgets/hydration_card.dart';
import 'package:fitpulse/state/hydration_providers.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory stand-in for the water table. Writes go into a list and are
/// re-emitted, so the card is exercised through its real reactive loop: tap,
/// write, stream emits, card rebuilds.
class _FakeHydrationRepository extends HydrationRepository {
  _FakeHydrationRepository()
      : super(AppDatabase.withExecutor(NativeDatabase.memory()));

  final List<WaterLog> rows = <WaterLog>[];
  final StreamController<List<WaterLog>> _changes =
      StreamController<List<WaterLog>>.broadcast();
  int _nextId = 1;

  Stream<List<WaterLog>> watch() async* {
    yield List<WaterLog>.of(rows);
    yield* _changes.stream;
  }

  void seed(List<int> amounts) {
    for (final int ml in amounts) {
      rows.add(
        WaterLog(
          id: _nextId++,
          amountMl: ml,
          loggedAt: DateTime(2026, 9, 16, 8).add(Duration(minutes: rows.length)),
        ),
      );
    }
  }

  @override
  Future<void> logDrink(int amountMl) async {
    rows.add(
      WaterLog(
        id: _nextId++,
        amountMl: amountMl,
        loggedAt: DateTime(2026, 9, 16, 9).add(Duration(minutes: rows.length)),
      ),
    );
    _changes.add(List<WaterLog>.of(rows));
  }

  @override
  Future<void> deleteWaterLog(int id) async {
    rows.removeWhere((WaterLog r) => r.id == id);
    _changes.add(List<WaterLog>.of(rows));
  }

  Future<void> close() => _changes.close();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<_FakeHydrationRepository> pumpCard(
    WidgetTester tester, {
    List<int> seed = const <int>[],
    int goalMl = 2500,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarded': true,
      'target_water_ml': goalMl,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final _FakeHydrationRepository repo = _FakeHydrationRepository()
      ..seed(seed);
    addTearDown(repo.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          hydrationRepositoryProvider.overrideWithValue(repo),
          // Bypass the real day clock, which arms a midnight timer.
          todayWaterLogsProvider.overrideWith((Ref ref) => repo.watch()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(411, 891),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(child: HydrationCard()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('starts empty with nothing to undo', (WidgetTester tester) async {
    await pumpCard(tester);

    expect(find.text('0 ml'), findsOneWidget);
    expect(find.text('of 2.5 L daily goal'), findsOneWidget);
    expect(find.text('2.5 L to go'), findsOneWidget);
    expect(find.text('Nothing logged yet today'), findsOneWidget);
    expect(find.byIcon(Icons.undo_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quick-add logs the preset and the total updates', (
    WidgetTester tester,
  ) async {
    final _FakeHydrationRepository repo = await pumpCard(tester);

    await tester.tap(find.text('+250 ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+500 ml'));
    await tester.pumpAndSettle();

    expect(repo.rows.map((WaterLog r) => r.amountMl), <int>[250, 500]);
    expect(find.text('750 ml'), findsOneWidget);
    expect(find.text('1.75 L to go'), findsOneWidget);
    expect(find.text('2 drinks today'), findsOneWidget);
  });

  testWidgets('undo removes only the most recent drink', (
    WidgetTester tester,
  ) async {
    final _FakeHydrationRepository repo =
        await pumpCard(tester, seed: <int>[250, 500]);

    expect(find.text('Undo 500 ml'), findsOneWidget);

    await tester.tap(find.text('Undo 500 ml'));
    await tester.pumpAndSettle();

    expect(repo.rows.map((WaterLog r) => r.amountMl), <int>[250]);
    expect(find.text('250 ml'), findsOneWidget);
    expect(find.text('Undo 250 ml'), findsOneWidget,
        reason: 'undo steps back through the day one drink at a time');
  });

  testWidgets('crossing the goal switches to the reached state', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, seed: <int>[1000, 1000], goalMl: 2500);
    expect(find.text('Goal reached'), findsNothing);

    await tester.tap(find.text('+500 ml'));
    await tester.pumpAndSettle();

    expect(find.text('Goal reached'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('custom amount is validated before it can be added', (
    WidgetTester tester,
  ) async {
    final _FakeHydrationRepository repo = await pumpCard(tester);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Log water'), findsOneWidget);

    // Out of range: no add, and the user is told why.
    await tester.enterText(find.byType(TextField), '5000');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Enter between 10 and 3000 ml.'), findsOneWidget);
    await tester.tap(find.text('ADD'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.rows, isEmpty);
    expect(find.text('Log water'), findsOneWidget, reason: 'sheet stays open');

    // A suggested size fills the field and enables the button.
    await tester.tap(find.text('330 ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD 330 ml'));
    await tester.pumpAndSettle();

    expect(repo.rows.map((WaterLog r) => r.amountMl), <int>[330]);
    expect(find.text('Log water'), findsNothing);
    expect(find.text('330 ml'), findsOneWidget);
  });

  testWidgets('fits a handset at the largest text scale the app allows', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, seed: <int>[1500, 750, 750], textScale: 1.15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the custom sheet disposes cleanly mid-edit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CustomWaterSheet()),
    ));
    await tester.enterText(find.byType(TextField), '42');
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(tester.takeException(), isNull);
  });
}
