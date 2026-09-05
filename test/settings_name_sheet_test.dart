import 'package:fitpulse/features/settings/settings_screen.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reproduction for the red screen shown after saving a new name from
/// Settings -> profile card:
///
///   'package:flutter/src/widgets/framework.dart': Failed assertion:
///   line 6281 pos 12: '_dependents.isEmpty': is not true.
void main() {
  testWidgets('editing the profile name and saving does not throw', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_name': 'Ali',
      'onboarded': true,
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

    // Open the name sheet from the profile card. GlassCard puts its InkWell
    // in a Positioned.fill above the content, so the tap lands on that
    // overlay rather than on the label itself.
    await tester.tap(find.text('Tap to change your name'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Your name'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Dany');
    await tester.pump();

    // Save - this is where the red screen appeared.
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
