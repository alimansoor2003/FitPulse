import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/data/repositories/hydration_repository.dart';
import 'package:fitpulse/domain/hydration.dart';
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
    List<String>? presets,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarded': true,
      'target_water_ml': goalMl,
      if (presets != null) 'water_presets_ml': presets,
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
    // With nothing logged the footer teaches the hold gesture instead.
    expect(
      find.text('Hold Glass or Bottle to change its amount'),
      findsOneWidget,
    );
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

  // ------------------------------------------------------ pinned presets

  /// Presses a preset and keeps the finger down for [hold].
  ///
  /// The extra 16ms pump starts the hold animation's ticker before the long
  /// pump: a ticker's first frame only records its start time, so without it
  /// the whole hold would measure as zero.
  Future<void> press(
    WidgetTester tester,
    String label,
    Duration hold,
  ) async {
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text(label)));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(hold);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('saved preset amounts are what the tiles show and log', (
    WidgetTester tester,
  ) async {
    final _FakeHydrationRepository repo =
        await pumpCard(tester, presets: <String>['300', '750']);

    expect(find.text('+300 ml'), findsOneWidget);
    expect(find.text('+750 ml'), findsOneWidget);

    await tester.tap(find.text('+750 ml'));
    await tester.pumpAndSettle();
    expect(repo.rows.map((WaterLog r) => r.amountMl), <int>[750]);
  });

  testWidgets('holding a preset for 2.5 s opens it for editing', (
    WidgetTester tester,
  ) async {
    final _FakeHydrationRepository repo = await pumpCard(tester);

    await press(tester, '+250 ml', kPresetHoldDuration);

    expect(find.text('Edit Glass'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '250',
      reason: 'the editor starts from the current amount',
    );
    expect(repo.rows, isEmpty, reason: 'a completed hold never logs a drink');
  });

  testWidgets('saving pins the new amount, persists it, and logs nothing', (
    WidgetTester tester,
  ) async {
    final _FakeHydrationRepository repo = await pumpCard(tester);

    await press(tester, '+250 ml', kPresetHoldDuration);
    await tester.enterText(find.byType(TextField), '400');
    await tester.pump();
    await tester.tap(find.text('SAVE 400 ml'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Glass'), findsNothing);
    expect(find.text('+400 ml'), findsOneWidget);
    expect(find.text('+250 ml'), findsNothing);
    expect(repo.rows, isEmpty);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('water_presets_ml'),
      <String>['400', '500'],
      reason: 'only the edited slot changes, and it survives a restart',
    );

    // And the pinned amount is what a tap now logs.
    await tester.tap(find.text('+400 ml'));
    await tester.pumpAndSettle();
    expect(repo.rows.map((WaterLog r) => r.amountMl), <int>[400]);
  });

  testWidgets('letting go part-way through a hold logs and edits nothing', (
    WidgetTester tester,
  ) async {
    final _FakeHydrationRepository repo = await pumpCard(tester);

    await press(tester, '+500 ml', const Duration(milliseconds: 1200));

    expect(find.text('Edit Bottle'), findsNothing);
    expect(repo.rows, isEmpty,
        reason: 'a hold abandoned half-way is not a tap');
  });

  testWidgets('dismissing the editor keeps the old amount', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester);

    await press(tester, '+500 ml', kPresetHoldDuration);
    expect(find.text('Edit Bottle'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '900');
    await tester.pump();
    // Close without saving: tap the barrier above the sheet.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(find.text('+500 ml'), findsOneWidget);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('water_presets_ml'), isNull);
  });
}

