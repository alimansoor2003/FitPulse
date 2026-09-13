import 'package:fitpulse/features/settings/settings_screen.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The BYOK onboarding lives entirely in this sheet, so it is worth asserting
/// that the link and the three steps are actually on screen - a user who
/// cannot find where to get a key cannot use the feature at all.
void main() {
  Future<void> pumpSettings(WidgetTester tester, {String key = ''}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_name': 'Ali',
      'onboarded': true,
      if (key.isNotEmpty) 'gemini_api_key': key,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// FadeIn staggers its entrance with Future.delayed, which schedules no
  /// frame - so pumpAndSettle returns with the timer still pending and the
  /// test tears down on top of it. Pumping past the longest stagger first
  /// lets those fire.
  Future<void> settle(WidgetTester tester) async {
    // Repeated, because each pump can build a row that was just scrolled into
    // view, and that row starts its own delay relative to the new clock.
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  /// The nutrition rows sit below the fold on a handset, so they have to be
  /// scrolled into view before they can be tapped.
  Future<void> openKeySheet(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('AI food parsing'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(find.text('AI food parsing'), warnIfMissed: false);
    await settle(tester);
  }

  testWidgets('the nutrition rows show the targets and an off state', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Daily targets'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(find.text('Daily targets'), findsOneWidget);
    expect(find.text('2000 kcal - P 150 / C 200 / F 65 g'), findsOneWidget);
    expect(
      find.text('Off - add a Gemini API key to turn it on'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stored key flips the row to connected', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester, key: 'AIzaTest');
    await tester.scrollUntilVisible(
      find.text('AI food parsing'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    expect(
      find.text('Connected - meal text is sent to Google Gemini'),
      findsOneWidget,
    );
  });

  testWidgets('the key sheet carries the link and the three steps', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);
    await openKeySheet(tester);

    expect(find.text('GET FREE GEMINI KEY'), findsOneWidget);
    expect(
      find.text('Tap "Get free Gemini key" and sign in with Google.'),
      findsOneWidget,
    );
    expect(find.text('Click "Create API key".'), findsOneWidget);
    expect(
      find.text('Copy the key and paste it in the box below.'),
      findsOneWidget,
    );
    expect(find.text('SAVE KEY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing key can be revealed and removed', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester, key: 'AIzaSecret');
    await openKeySheet(tester);

    final Finder field = find.byType(TextField).last;
    expect(tester.widget<TextField>(field).obscureText, isTrue,
        reason: 'the key must not sit on screen in plain text');

    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump();
    expect(tester.widget<TextField>(field).obscureText, isFalse);

    expect(find.text('Remove key'), findsOneWidget);
  });

  testWidgets('the privacy line separates local workouts from AI parsing', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    // The footer is the last row of a long ListView, so it has to be
    // scrolled into existence before it can be asserted on.
    await tester.scrollUntilVisible(
      find.textContaining('workout logs remain 100% local'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);

    expect(
      find.textContaining('workout logs remain 100% local on your phone'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Google Gemini API using your personal key'),
      findsOneWidget,
    );
  });
}
