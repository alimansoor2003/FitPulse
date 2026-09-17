import 'package:fitpulse/features/onboarding/onboarding_screen.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// A Galaxy S24 Ultra-sized screen, with the keyboard up when
  /// [keyboard] is non-zero.
  Future<void> pump(
    WidgetTester tester, {
    double keyboard = 0,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    // The hero animates forever, so step past the card's fade-in by hand.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('shows the hero when there is room for it', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a small phone fits without overflowing', (
    WidgetTester tester,
  ) async {
    await pump(tester, textScale: 1.15);
    tester.view.physicalSize = const Size(360, 640);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the keyboard never overflows the card', (
    WidgetTester tester,
  ) async {
    await pump(tester, keyboard: 420, textScale: 1.15);
    expect(tester.takeException(), isNull);
    expect(find.text('GET STARTED'), findsOneWidget);
  });

  testWidgets('with the keyboard up the hero steps aside', (
    WidgetTester tester,
  ) async {
    await pump(tester, keyboard: 420);
    expect(
      find.byIcon(Icons.fitness_center_rounded),
      findsNothing,
      reason: 'squeezed, it collapsed into a starburst over the card',
    );
  });
}
