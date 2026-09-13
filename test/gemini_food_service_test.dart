import 'dart:convert';

import 'package:fitpulse/data/services/gemini_food_service.dart';
import 'package:fitpulse/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wraps [items] the way the Gemini REST API does: the model's JSON payload
/// arrives as text inside candidates[0].content.parts.
String geminiEnvelope(Object items) {
  return jsonEncode(<String, Object?>{
    'candidates': <Object>[
      <String, Object?>{
        'finishReason': 'STOP',
        'content': <String, Object?>{
          'role': 'model',
          'parts': <Object>[
            <String, Object?>{'text': jsonEncode(items)},
          ],
        },
      },
    ],
  });
}

void main() {
  const String key = 'test-key';

  GeminiFoodService serviceReturning(
    String body, {
    int status = 200,
    void Function(http.Request)? onRequest,
  }) {
    return GeminiFoodService(
      client: MockClient((http.Request request) async {
        onRequest?.call(request);
        return http.Response(
          body,
          status,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  }

  group('parseMeal', () {
    test('turns the model reply into food items', () async {
      final GeminiFoodService service = serviceReturning(
        geminiEnvelope(<Object>[
          <String, Object?>{
            'name': 'Scrambled eggs',
            'mealType': 'Breakfast',
            'calories': 210,
            'proteinG': 18.5,
            'carbsG': 1.2,
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
      );
      addTearDown(service.dispose);

      final List<ParsedFood> items = await service.parseMeal(
        '3 eggs and a black coffee',
        apiKey: key,
        defaultMeal: MealType.breakfast,
      );

      expect(items, hasLength(2));
      expect(items.first.name, 'Scrambled eggs');
      expect(items.first.mealType, MealType.breakfast);
      expect(items.first.calories, 210);
      expect(items.first.proteinG, 18.5);
      // Local ids must be unique so the review list can key rows by them.
      expect(items.map((ParsedFood f) => f.localId).toSet(), hasLength(2));
    });

    test('asks for structured JSON and keeps the key out of the URL', () async {
      http.Request? captured;
      final GeminiFoodService service = serviceReturning(
        geminiEnvelope(<Object>[
          <String, Object?>{
            'name': 'Toast',
            'mealType': 'Breakfast',
            'calories': 90,
            'proteinG': 3,
            'carbsG': 17,
            'fatG': 1,
          },
        ]),
        onRequest: (http.Request request) => captured = request,
      );
      addTearDown(service.dispose);

      await service.parseMeal(
        'a slice of toast',
        apiKey: key,
        defaultMeal: MealType.breakfast,
      );

      final http.Request request = captured!;
      expect(request.url.path, contains(GeminiFoodService.model));
      expect(request.url.query, isEmpty, reason: 'no key in the query string');
      expect(request.headers['x-goog-api-key'], key);

      final Map<String, Object?> body =
          jsonDecode(request.body) as Map<String, Object?>;
      final Map<String, Object?> config =
          body['generationConfig']! as Map<String, Object?>;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseSchema'], isNotNull);
      // The default meal has to reach the model, not just the local fallback.
      expect(request.body, contains('Breakfast'));
    });

    test('falls back to the default meal when the model omits one', () async {
      final GeminiFoodService service = serviceReturning(
        geminiEnvelope(<Object>[
          <String, Object?>{'name': 'Rice', 'calories': 200},
        ]),
      );
      addTearDown(service.dispose);

      final List<ParsedFood> items = await service.parseMeal(
        'rice',
        apiKey: key,
        defaultMeal: MealType.dinner,
      );

      expect(items.single.mealType, MealType.dinner);
      expect(items.single.calories, 200);
      expect(items.single.proteinG, 0);
    });
  });

  group('failures', () {
    test('never touches the network without an API key', () async {
      bool called = false;
      final GeminiFoodService service = GeminiFoodService(
        client: MockClient((http.Request request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('eggs', apiKey: '', defaultMeal: MealType.breakfast),
        throwsA(
          isA<FoodParseException>()
              .having((FoodParseException e) => e.canRetry, 'canRetry', isFalse),
        ),
      );
      expect(called, isFalse, reason: 'opt-in means no request at all');
    });

    test('a rejected key is not offered as retryable', () async {
      final GeminiFoodService service = serviceReturning(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{'message': 'API key not valid'},
        }),
        status: 403,
      );
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('eggs', apiKey: key, defaultMeal: MealType.breakfast),
        throwsA(
          isA<FoodParseException>()
              .having((FoodParseException e) => e.canRetry, 'canRetry', isFalse)
              .having(
                (FoodParseException e) => e.message,
                'message',
                contains('Settings'),
              ),
        ),
      );
    });

    test('a rate limit is retryable', () async {
      final GeminiFoodService service =
          serviceReturning('{"error":{"message":"quota"}}', status: 429);
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('eggs', apiKey: key, defaultMeal: MealType.breakfast),
        throwsA(
          isA<FoodParseException>()
              .having((FoodParseException e) => e.canRetry, 'canRetry', isTrue),
        ),
      );
    });

    test('a server error is reported without leaking the body', () async {
      final GeminiFoodService service =
          serviceReturning('<html>502 Bad Gateway</html>', status: 502);
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('eggs', apiKey: key, defaultMeal: MealType.breakfast),
        throwsA(
          isA<FoodParseException>().having(
            (FoodParseException e) => e.message,
            'message',
            isNot(contains('html')),
          ),
        ),
      );
    });

    test('prose instead of JSON becomes a readable error', () async {
      final GeminiFoodService service = serviceReturning(
        jsonEncode(<String, Object?>{
          'candidates': <Object>[
            <String, Object?>{
              'content': <String, Object?>{
                'parts': <Object>[
                  <String, Object?>{'text': 'I am not sure what you ate.'},
                ],
              },
            },
          ],
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('???', apiKey: key, defaultMeal: MealType.snack),
        throwsA(isA<FoodParseException>()),
      );
    });

    test('an empty array asks the user to rephrase', () async {
      final GeminiFoodService service =
          serviceReturning(geminiEnvelope(<Object>[]));
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('hello', apiKey: key, defaultMeal: MealType.snack),
        throwsA(
          isA<FoodParseException>()
              .having((FoodParseException e) => e.canRetry, 'canRetry', isFalse),
        ),
      );
    });

    test('a blocked prompt is not retried', () async {
      final GeminiFoodService service = serviceReturning(
        jsonEncode(<String, Object?>{
          'promptFeedback': <String, Object?>{'blockReason': 'SAFETY'},
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('...', apiKey: key, defaultMeal: MealType.snack),
        throwsA(
          isA<FoodParseException>()
              .having((FoodParseException e) => e.canRetry, 'canRetry', isFalse),
        ),
      );
    });

    test('blank input is rejected before any request', () async {
      bool called = false;
      final GeminiFoodService service = GeminiFoodService(
        client: MockClient((http.Request request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.parseMeal('   ', apiKey: key, defaultMeal: MealType.snack),
        throwsA(isA<FoodParseException>()),
      );
      expect(called, isFalse);
    });
  });
}
