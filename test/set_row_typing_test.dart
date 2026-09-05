import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/domain/models.dart';
import 'package:fitpulse/features/workout/widgets/set_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the "typing feels laggy and choppy" bug.
///
/// Two things went wrong before:
///   1. Every keystroke wrote to SQLite, which made the Drift stream re-emit
///      and rebuild every set row in the session.
///   2. A write that landed after the next character was typed came back
///      stale and overwrote the field, so characters visibly reverted.
void main() {
  SetLog log({double weightKg = 0, int reps = 0}) => SetLog(
        id: 1,
        sessionId: 1,
        exerciseId: 1,
        setIndex: 1,
        weightKg: weightKg,
        reps: reps,
        completed: false,
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<void> pumpRow(
    WidgetTester tester, {
    required SetLog current,
    required void Function(double) onWeight,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetRow(
            log: current,
            ghost: const GhostSet(weightKg: 40, reps: 8),
            onWeightChanged: onWeight,
            onRepsChanged: (_) {},
            onToggle: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('batches rapid keystrokes into a single write', (
    WidgetTester tester,
  ) async {
    final List<double> writes = <double>[];
    await pumpRow(tester, current: log(), onWeight: writes.add);

    final Finder weightField = find.byType(TextField).first;

    // Three characters typed faster than the debounce window.
    await tester.enterText(weightField, '1');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(weightField, '12');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(weightField, '125');

    // Nothing should have hit the database yet.
    expect(writes, isEmpty);

    await tester.pump(const Duration(milliseconds: 500));

    // Exactly one write, carrying the final value.
    expect(writes, <double>[125]);
  });

  testWidgets('a stale value arriving mid-edit does not clobber the field', (
    WidgetTester tester,
  ) async {
    final List<double> writes = <double>[];
    await pumpRow(tester, current: log(), onWeight: writes.add);

    final Finder weightField = find.byType(TextField).first;
    await tester.enterText(weightField, '42');
    await tester.pump(const Duration(milliseconds: 50));

    // The parent rebuilds with the row as the database still knows it -
    // empty. This is exactly the race that used to erase typed characters.
    await pumpRow(tester, current: log(), onWeight: writes.add);
    await tester.pump();

    expect(
      tester.widget<TextField>(weightField).controller!.text,
      '42',
      reason: 'typed text must survive a stale rebuild',
    );
  });

  testWidgets('flushes the pending write when the row is disposed', (
    WidgetTester tester,
  ) async {
    final List<double> writes = <double>[];
    await pumpRow(tester, current: log(), onWeight: writes.add);

    await tester.enterText(find.byType(TextField).first, '60');
    await tester.pump(const Duration(milliseconds: 50));

    // Leave the screen before the debounce timer fires.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    expect(writes, <double>[60], reason: 'in-flight edit must not be lost');
  });

  testWidgets('accepts the database value when the field is idle', (
    WidgetTester tester,
  ) async {
    await pumpRow(tester, current: log(), onWeight: (_) {});
    await pumpRow(tester, current: log(weightKg: 77.5), onWeight: (_) {});
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '77.5',
    );
  });
}
