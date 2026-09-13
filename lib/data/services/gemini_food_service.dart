import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../domain/nutrition.dart';

/// Where a user creates the key this service needs. Linked from Settings.
const String kGeminiKeyUrl = 'https://aistudio.google.com/app/apikey';

/// A failure the food logger can explain to the user in one line.
///
/// Everything that can go wrong on the way to a parsed meal - no key, no
/// network, a rejected request, an unreadable reply - is funnelled into this
/// so the sheet has exactly one error shape to render.
class FoodParseException implements Exception {
  const FoodParseException(this.message, {this.canRetry = true});

  /// Shown verbatim in the review sheet, so it is written for a human.
  final String message;

  /// False when retrying the identical request cannot help (a missing or
  /// rejected API key), which hides the Retry button.
  final bool canRetry;

  @override
  String toString() => 'FoodParseException: $message';
}

/// Turns a sentence such as "3 eggs, 2 slices of sourdough toast and a black
/// coffee" into a list of [ParsedFood].
///
/// This talks to the Gemini REST endpoint directly with `package:http` rather
/// than through an SDK: the call is a single POST, and the official Dart
/// package for it is unlisted on pub.dev while its replacement drags in the
/// whole Firebase stack for what is one HTTP request.
class GeminiFoodService {
  GeminiFoodService({http.Client? client, this.timeout = _defaultTimeout})
      : _client = client ?? http.Client();

  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Overridable so tests can drive the parser without a socket.
  final http.Client _client;
  final Duration timeout;

  /// The model this ships pointing at.
  ///
  /// Google retires these faster than the app ships: gemini-1.5-flash was
  /// gone before the first build, and gemini-2.5-flash started 404ing for new
  /// keys shortly after. See [_replacementModelFrom] - a 404 that names its
  /// own successor is followed automatically rather than dead-ending on the
  /// user.
  static const String model = 'gemini-3.6-flash';
  static const String _host = 'generativelanguage.googleapis.com';

  /// The model actually in use. Starts at [model] and moves if Google tells
  /// us to, for the life of this service instance.
  String _activeModel = model;

  String get activeModel => _activeModel;

  bool _closed = false;

  /// Releases the underlying connection pool. Called from the provider's
  /// `onDispose`, so the socket does not outlive the app state that owns it.
  void dispose() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }

  static const String _systemInstruction =
      'You are a nutrition parser for a fitness app. The user describes what '
      'they ate in plain language. Split it into individual food items and '
      'estimate the nutrition of each one.\n'
      'Rules:\n'
      '- One array entry per distinct food or drink.\n'
      '- Respect stated quantities ("3 eggs" is three eggs, not one).\n'
      '- When no quantity is given, assume one common serving.\n'
      '- calories is whole kilocalories; proteinG, carbsG and fatG are grams '
      'and may have one decimal.\n'
      '- Use 0 rather than null for anything negligible (black coffee, water).\n'
      '- name is a short human label, at most six words, in English.\n'
      '- mealType must be exactly one of Breakfast, Lunch, Dinner, Snack. '
      'Infer it from the food and any time words in the text; when it is not '
      'inferable use the meal named as the default below.\n'
      '- If the text describes no food at all, return an empty array.';

  /// The structured-output contract. Gemini validates its own reply against
  /// this, which is what lets the client `jsonDecode` without defensive
  /// unwrapping of prose or markdown fences.
  static Map<String, Object?> get responseSchema => <String, Object?>{
        'type': 'ARRAY',
        'items': <String, Object?>{
          'type': 'OBJECT',
          'properties': <String, Object?>{
            'name': <String, Object?>{'type': 'STRING'},
            'mealType': <String, Object?>{
              'type': 'STRING',
              'enum': <String>[
                for (final MealType type in MealType.values) type.label,
              ],
            },
            'calories': <String, Object?>{'type': 'INTEGER'},
            'proteinG': <String, Object?>{'type': 'NUMBER'},
            'carbsG': <String, Object?>{'type': 'NUMBER'},
            'fatG': <String, Object?>{'type': 'NUMBER'},
          },
          'propertyOrdering': <String>[
            'name',
            'mealType',
            'calories',
            'proteinG',
            'carbsG',
            'fatG',
          ],
          'required': <String>[
            'name',
            'mealType',
            'calories',
            'proteinG',
            'carbsG',
            'fatG',
          ],
        },
      };

  /// Parses [description] into food items.
  ///
  /// [defaultMeal] is both sent to the model as the fallback meal and used
  /// locally for any item that still comes back without one.
  Future<List<ParsedFood>> parseMeal(
    String description, {
    required String apiKey,
    required MealType defaultMeal,
  }) async {
    final String text = description.trim();
    if (text.isEmpty) {
      throw const FoodParseException(
        'Describe what you ate first.',
        canRetry: false,
      );
    }
    if (apiKey.trim().isEmpty) {
      throw const FoodParseException(
        'No Gemini API key yet. Add one in Settings, or log this meal '
        'manually.',
        canRetry: false,
      );
    }

    return _send(
      text,
      apiKey: apiKey.trim(),
      defaultMeal: defaultMeal,
      followModelChange: true,
    );
  }

  /// One request/response cycle against [_activeModel].
  ///
  /// [followModelChange] is true only for the first attempt, so a deprecation
  /// 404 costs at most one extra round trip and can never loop.
  Future<List<ParsedFood>> _send(
    String text, {
    required String apiKey,
    required MealType defaultMeal,
    required bool followModelChange,
  }) async {
    // The key travels as a header, not a query parameter, so it cannot be
    // captured by anything that logs request URLs.
    final Uri uri =
        Uri.https(_host, '/v1beta/models/$_activeModel:generateContent');
    final String body = jsonEncode(<String, Object?>{
      'systemInstruction': <String, Object?>{
        'parts': <Object>[
          <String, Object?>{'text': _systemInstruction},
        ],
      },
      'contents': <Object>[
        <String, Object?>{
          'role': 'user',
          'parts': <Object>[
            <String, Object?>{
              'text': 'Default meal: ${defaultMeal.label}\n'
                  'The user ate: $text',
            },
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
        'temperature': 0.2,
      },
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const FoodParseException(
        'Gemini took too long to answer. Try again, or log it manually.',
      );
    } on SocketException {
      throw const FoodParseException(
        'No internet connection. You can still log this meal manually.',
      );
    } on http.ClientException catch (error) {
      throw FoodParseException('Could not reach Gemini: ${error.message}');
    }

    if (response.statusCode != 200) {
      final String? replacement =
          followModelChange ? _replacementModelFrom(response) : null;
      if (replacement != null) {
        _activeModel = replacement;
        return _send(
          text,
          apiKey: apiKey,
          defaultMeal: defaultMeal,
          followModelChange: false,
        );
      }
      throw _httpFailure(response);
    }

    return _itemsFrom(response.body, defaultMeal: defaultMeal);
  }

  /// The successor model named in a deprecation 404, if there is one.
  ///
  /// Google's own message spells it out - "This model models/gemini-2.5-flash
  /// is no longer available to new users. Please update your code to use
  /// models/gemini-3.6-flash" - so the retirement carries its own fix. Taking
  /// it means the app keeps working the day a model is pulled instead of
  /// showing the user a 404 they cannot act on.
  String? _replacementModelFrom(http.Response response) {
    if (response.statusCode != 404) return null;
    final Iterable<RegExpMatch> matches =
        RegExp(r'models/([A-Za-z0-9._-]+)').allMatches(response.body);
    for (final RegExpMatch match in matches.toList().reversed) {
      final String name = match.group(1)!;
      if (name != _activeModel) return name;
    }
    return null;
  }

  FoodParseException _httpFailure(http.Response response) {
    final int code = response.statusCode;
    // Gemini reports errors as {"error": {"message": ...}}; fall back to the
    // status line when the body is not the shape we expect.
    String? detail;
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) {
        final Object? error = decoded['error'];
        if (error is Map<String, Object?>) {
          detail = error['message']?.toString();
        }
      }
    } on FormatException {
      detail = null;
    }

    switch (code) {
      case 400:
        return FoodParseException(
          'Gemini rejected the request${detail == null ? '' : ': $detail'}',
        );
      case 401:
      case 403:
        return const FoodParseException(
          'That API key was refused. Check it in Settings - it needs the '
          'Generative Language API enabled.',
          canRetry: false,
        );
      case 429:
        return const FoodParseException(
          'Rate limit reached on this key. Wait a moment and try again.',
        );
      default:
        if (code >= 500) {
          return const FoodParseException(
            'Gemini is having a moment (server error). Try again shortly.',
          );
        }
        return FoodParseException(
          'Gemini returned $code${detail == null ? '' : ': $detail'}',
        );
    }
  }

  List<ParsedFood> _itemsFrom(String responseBody, {required MealType defaultMeal}) {
    final Object? envelope;
    try {
      envelope = jsonDecode(responseBody);
    } on FormatException {
      throw const FoodParseException('Gemini sent a reply we could not read.');
    }
    if (envelope is! Map<String, Object?>) {
      throw const FoodParseException('Gemini sent a reply we could not read.');
    }

    final Object? blockReason =
        (envelope['promptFeedback'] as Map<String, Object?>?)?['blockReason'];
    if (blockReason != null) {
      throw const FoodParseException(
        'Gemini declined to answer that one. Reword it, or log it manually.',
        canRetry: false,
      );
    }

    final Object? candidates = envelope['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FoodParseException(
        'Gemini returned nothing. Try again, or log it manually.',
      );
    }
    final Object? first = candidates.first;
    if (first is! Map<String, Object?>) {
      throw const FoodParseException('Gemini sent a reply we could not read.');
    }
    if (first['finishReason'] == 'MAX_TOKENS') {
      throw const FoodParseException(
        'That meal was too long to parse in one go. Split it up and try '
        'again.',
      );
    }

    final StringBuffer payload = StringBuffer();
    final Object? content = first['content'];
    if (content is Map<String, Object?>) {
      final Object? parts = content['parts'];
      if (parts is List) {
        for (final Object? part in parts) {
          if (part is Map<String, Object?> && part['text'] is String) {
            payload.write(part['text'] as String);
          }
        }
      }
    }
    if (payload.isEmpty) {
      throw const FoodParseException(
        'Gemini returned an empty answer. Try again, or log it manually.',
      );
    }

    final Object? items;
    try {
      items = jsonDecode(payload.toString());
    } on FormatException {
      throw const FoodParseException(
        'Gemini did not return valid JSON. Try again, or log it manually.',
      );
    }
    if (items is! List) {
      throw const FoodParseException(
        'Gemini did not return a list of foods. Try rephrasing it.',
      );
    }

    int nextId = 0;
    final List<ParsedFood> parsed = <ParsedFood>[
      for (final Object? item in items)
        if (item is Map<String, Object?>)
          ParsedFood.fromJson(
            item,
            localId: nextId++,
            fallbackMeal: defaultMeal,
          ),
    ];

    if (parsed.isEmpty) {
      throw const FoodParseException(
        'No food found in that. Describe what you ate, for example '
        '"3 eggs and two slices of toast".',
        canRetry: false,
      );
    }
    return parsed;
  }
}
