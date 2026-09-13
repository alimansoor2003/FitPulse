import 'dart:convert';

import 'package:fitpulse/data/services/gemini_food_service.dart';
import 'package:fitpulse/features/nutrition/food_logger_sheet.dart';
import 'package:fitpulse/state/nutrition_providers.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two items, as the Gemini REST envelope delivers them.
String _twoItems() => jsonEncode(<String, Object?>{
      'candidates': <Object>[
        <String, Object?>{
          'content': <String, Object?>{
            'parts': <Object>[
              <String, Object?>{
                'text': jsonEncode(<Object>[
                  <String, Object?>{
                    'name': 'Scrambled eggs',
                    'mealType': 'Breakfast',
                    'calories': 210,
                    'proteinG': 18,
                    'carbsG': 1,
                    'fatG': 15,
                  },
                  <String, Object?>{
                    'name': 'Black coffee',
                    'mealType': 'Breakfast',
                    'calories': 2,
                    'proteinG': 0,
                    'carbsG': 0,
                    'fatG': 0,
                  },
                ]),
              },
            ],
          },
        },
      ],
    });

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required http.Response Function(http.Request) respond,
    String apiKey = 'test-key',
  }) async {
    // A phone-shaped surface rather than the 800x600 default: the review list
    // has to lay out at real handset width without overflowing, and the rows
    // must stay hit-testable instead of being clipped out of the viewport.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_name': 'Ali',
      'onboarded': true,
      if (apiKey.isNotEmpty) 'gemini_api_key': apiKey,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final GeminiFoodService service = GeminiFoodService(
      client: MockClient((http.Request request) async => respond(request)),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          geminiFoodServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FoodLoggerSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('parses a description into an editable review list', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      respond: (_) => http.Response(_twoItems(), 200),
    );

    expect(find.text('Log Food'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      '3 eggs and a black coffee',
    );
    await tester.tap(find.text('PARSE WITH AI'));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Scrambled eggs'), findsOneWidget);
    expect(find.text('Black coffee'), findsOneWidget);
    // 210 + 2 kcal, shown in the running total.
    expect(find.text('212'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing a macro updates the running total', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester, respond: (_) => http.Response(_twoItems(), 200));

    await tester.enterText(find.byType(TextField).first, '3 eggs');
    await tester.tap(find.text('PARSE WITH AI'));
    await tester.pumpAndSettle();

    // Fields per row are name, kcal, P, C, F - so index 1 is the first
    // calorie field.
    await tester.enterText(find.byType(TextField).at(1), '500');
    await tester.pump();

    expect(find.text('502'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Scrambled eggs',
      reason: 'editing one row must not disturb its neighbours',
    );
  });

  testWidgets('removing a row drops it from the total', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester, respond: (_) => http.Response(_twoItems(), 200));

    await tester.enterText(find.byType(TextField).first, '3 eggs');
    await tester.tap(find.text('PARSE WITH AI'));
    await tester.pumpAndSettle();

    // Every row is swipeable; the X button is the same code path, and is the
    // one a test can drive without fighting the text field's own drag
    // recogniser for the gesture.
    expect(find.byType(Dismissible), findsNWidgets(2));

    await tester.ensureVisible(find.byIcon(Icons.close_rounded).at(1));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Black coffee'), findsNothing);
    expect(find.byType(Dismissible), findsOneWidget);
    // The surviving row's own calorie field, plus the total that now matches
    // it because the 2 kcal coffee is gone.
    expect(find.text('210'), findsNWidgets(2));
    expect(
      tester.takeException(),
      isNull,
      reason: 'the removed row still feeds the totals listener',
    );
  });

  testWidgets('a failed request offers retry and manual entry', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      respond: (_) => http.Response('{"error":{"message":"quota"}}', 429),
    );

    await tester.enterText(find.byType(TextField).first, '3 eggs');
    await tester.tap(find.text('PARSE WITH AI'));
    await tester.pumpAndSettle();

    expect(find.text("That didn't work"), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('Log manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected key hides retry but keeps manual entry', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      respond: (_) => http.Response('{"error":{"message":"bad key"}}', 403),
    );

    await tester.enterText(find.byType(TextField).first, '3 eggs');
    await tester.tap(find.text('PARSE WITH AI'));
    await tester.pumpAndSettle();

    expect(find.text('TRY AGAIN'), findsNothing);
    expect(find.text('Log manually'), findsOneWidget);

    // The manual fallback must reach the same review list, offline.
    await tester.tap(find.text('Log manually'));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('without an API key nothing is sent and manual entry is offered',
      (WidgetTester tester) async {
    bool called = false;
    await pumpSheet(
      tester,
      apiKey: '',
      respond: (_) {
        called = true;
        return http.Response('{}', 200);
      },
    );

    expect(find.text('PARSE WITH AI'), findsNothing);
    // The prompt has to be actionable, not just informative.
    expect(find.text('ADD API KEY IN SETTINGS'), findsOneWidget);
    expect(find.text('Log manually'), findsOneWidget);

    await tester.tap(find.text('Log manually'));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Food name'), findsOneWidget, reason: 'one blank row');
    expect(called, isFalse);
  });

  testWidgets('disposing the sheet mid-edit does not throw', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester, respond: (_) => http.Response(_twoItems(), 200));

    await tester.enterText(find.byType(TextField).first, '3 eggs');
    await tester.tap(find.text('PARSE WITH AI'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(2), '30');
    await tester.pump();

    // Leaving the screen has to dispose every per-row controller, including
    // the ones behind the totals listener.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
