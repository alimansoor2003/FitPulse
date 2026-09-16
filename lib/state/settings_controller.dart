import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/hydration.dart';
import '../domain/nutrition.dart';

/// Injected in `main()` once SharedPreferences has loaded.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

class AppSettings {
  const AppSettings({
    required this.userName,
    required this.onboarded,
    required this.defaultRestSeconds,
    required this.autoStartRest,
    required this.showArabicNames,
    required this.weightStep,
    required this.weeklyGoal,
    required this.geminiApiKey,
    required this.macroTargets,
    required this.waterGoalMl,
    required this.waterPresetsMl,
  });

  final String userName;
  final bool onboarded;
  final int defaultRestSeconds;
  final bool autoStartRest;
  final bool showArabicNames;
  final double weightStep;
  final int weeklyGoal;

  /// Pasted by the user in Settings. Empty until they opt in to AI parsing.
  final String geminiApiKey;
  final MacroTargets macroTargets;

  /// Daily hydration goal the Today ring fills against.
  final int waterGoalMl;

  static const int defaultWaterGoalMl = 2500;
  static const int minWaterGoalMl = 500;
  static const int maxWaterGoalMl = 6000;
  static const int waterGoalStepMl = 250;

  /// What each pinned quick-add slot logs, in [kWaterPresetLabels] order.
  final List<int> waterPresetsMl;

  /// Compiled in for developer builds with
  /// `flutter run --dart-define=GEMINI_API_KEY=...`. Never committed, and the
  /// pasted key always wins so a shipped build can be re-pointed without a
  /// rebuild.
  static const String buildTimeGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY');

  /// The key actually used for a request, or empty when the feature is off.
  String get effectiveGeminiKey =>
      geminiApiKey.trim().isNotEmpty ? geminiApiKey.trim() : buildTimeGeminiKey;

  /// AI food parsing is opt-in: having a key *is* the opt-in. Without one the
  /// app never touches the network and the logger offers manual entry only.
  bool get aiFoodEnabled => effectiveGeminiKey.isNotEmpty;

  static const AppSettings fallback = AppSettings(
    userName: 'Athlete',
    onboarded: false,
    defaultRestSeconds: 90,
    autoStartRest: true,
    showArabicNames: true,
    weightStep: 2.5,
    weeklyGoal: 3,
    geminiApiKey: '',
    macroTargets: MacroTargets.fallback,
    waterGoalMl: defaultWaterGoalMl,
    waterPresetsMl: kDefaultWaterPresetsMl,
  );

  AppSettings copyWith({
    String? userName,
    bool? onboarded,
    int? defaultRestSeconds,
    bool? autoStartRest,
    bool? showArabicNames,
    double? weightStep,
    int? weeklyGoal,
    String? geminiApiKey,
    MacroTargets? macroTargets,
    int? waterGoalMl,
    List<int>? waterPresetsMl,
  }) {
    return AppSettings(
      userName: userName ?? this.userName,
      onboarded: onboarded ?? this.onboarded,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      autoStartRest: autoStartRest ?? this.autoStartRest,
      showArabicNames: showArabicNames ?? this.showArabicNames,
      weightStep: weightStep ?? this.weightStep,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      macroTargets: macroTargets ?? this.macroTargets,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      waterPresetsMl: waterPresetsMl ?? this.waterPresetsMl,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const String _kName = 'user_name';
  static const String _kOnboarded = 'onboarded';
  static const String _kRest = 'default_rest_seconds';
  static const String _kAutoRest = 'auto_start_rest';
  static const String _kArabic = 'show_arabic_names';
  static const String _kStep = 'weight_step';
  static const String _kGoal = 'weekly_goal';
  static const String _kGeminiKey = 'gemini_api_key';
  static const String _kCalories = 'target_calories';
  static const String _kProtein = 'target_protein_g';
  static const String _kCarbs = 'target_carbs_g';
  static const String _kFat = 'target_fat_g';
  static const String _kWater = 'target_water_ml';
  static const String _kWaterPresets = 'water_presets_ml';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final SharedPreferences prefs = _prefs;
    return AppSettings(
      userName: prefs.getString(_kName) ?? AppSettings.fallback.userName,
      onboarded: prefs.getBool(_kOnboarded) ?? false,
      defaultRestSeconds: prefs.getInt(_kRest) ?? 90,
      autoStartRest: prefs.getBool(_kAutoRest) ?? true,
      showArabicNames: prefs.getBool(_kArabic) ?? true,
      weightStep: prefs.getDouble(_kStep) ?? 2.5,
      weeklyGoal: prefs.getInt(_kGoal) ?? 3,
      geminiApiKey: prefs.getString(_kGeminiKey) ?? '',
      macroTargets: MacroTargets(
        calories: prefs.getInt(_kCalories) ?? MacroTargets.fallback.calories,
        proteinG: prefs.getDouble(_kProtein) ?? MacroTargets.fallback.proteinG,
        carbsG: prefs.getDouble(_kCarbs) ?? MacroTargets.fallback.carbsG,
        fatG: prefs.getDouble(_kFat) ?? MacroTargets.fallback.fatG,
      ),
      waterGoalMl:
          prefs.getInt(_kWater) ?? AppSettings.defaultWaterGoalMl,
      waterPresetsMl: waterPresetsFrom(prefs.getStringList(_kWaterPresets)),
    );
  }

  Future<void> completeOnboarding(String name) async {
    final String clean = name.trim().isEmpty ? 'Athlete' : name.trim();
    await _prefs.setString(_kName, clean);
    await _prefs.setBool(_kOnboarded, true);
    state = state.copyWith(userName: clean, onboarded: true);
  }

  Future<void> setName(String name) async {
    final String clean = name.trim().isEmpty ? 'Athlete' : name.trim();
    await _prefs.setString(_kName, clean);
    state = state.copyWith(userName: clean);
  }

  Future<void> setDefaultRest(int seconds) async {
    final int clamped = seconds.clamp(15, 300).toInt();
    await _prefs.setInt(_kRest, clamped);
    state = state.copyWith(defaultRestSeconds: clamped);
  }

  Future<void> setAutoStartRest(bool value) async {
    await _prefs.setBool(_kAutoRest, value);
    state = state.copyWith(autoStartRest: value);
  }

  Future<void> setShowArabicNames(bool value) async {
    await _prefs.setBool(_kArabic, value);
    state = state.copyWith(showArabicNames: value);
  }

  Future<void> setWeightStep(double value) async {
    await _prefs.setDouble(_kStep, value);
    state = state.copyWith(weightStep: value);
  }

  Future<void> setWeeklyGoal(int value) async {
    final int clamped = value.clamp(1, 7).toInt();
    await _prefs.setInt(_kGoal, clamped);
    state = state.copyWith(weeklyGoal: clamped);
  }

  /// Stores the Gemini key. Passing an empty string opts back out of AI
  /// parsing and clears the stored value entirely.
  Future<void> setGeminiApiKey(String key) async {
    final String clean = key.trim();
    if (clean.isEmpty) {
      await _prefs.remove(_kGeminiKey);
    } else {
      await _prefs.setString(_kGeminiKey, clean);
    }
    state = state.copyWith(geminiApiKey: clean);
  }

  /// Sets the daily water goal, snapped to the 250 ml step the stepper uses
  /// and clamped to a range no one would reach by accident.
  Future<void> setWaterGoal(int ml) async {
    final int snapped = (ml / AppSettings.waterGoalStepMl).round() *
        AppSettings.waterGoalStepMl;
    final int clamped = snapped
        .clamp(AppSettings.minWaterGoalMl, AppSettings.maxWaterGoalMl)
        .toInt();
    await _prefs.setInt(_kWater, clamped);
    state = state.copyWith(waterGoalMl: clamped);
  }

  /// Re-pins the quick-add slot at [index] to [ml], clamped to what a single
  /// drink can be.
  Future<void> setWaterPreset(int index, int ml) async {
    if (index < 0 || index >= state.waterPresetsMl.length) return;
    final List<int> next = List<int>.of(state.waterPresetsMl);
    next[index] = ml.clamp(kMinDrinkMl, kMaxDrinkMl).toInt();
    await _prefs.setStringList(
      _kWaterPresets,
      <String>[for (final int value in next) '$value'],
    );
    state = state.copyWith(waterPresetsMl: next);
  }

  Future<void> setMacroTargets(MacroTargets targets) async {
    final MacroTargets clamped = MacroTargets(
      calories: targets.calories.clamp(500, 8000),
      proteinG: targets.proteinG.clamp(0.0, 500.0),
      carbsG: targets.carbsG.clamp(0.0, 1000.0),
      fatG: targets.fatG.clamp(0.0, 400.0),
    );
    await _prefs.setInt(_kCalories, clamped.calories);
    await _prefs.setDouble(_kProtein, clamped.proteinG);
    await _prefs.setDouble(_kCarbs, clamped.carbsG);
    await _prefs.setDouble(_kFat, clamped.fatG);
    state = state.copyWith(macroTargets: clamped);
  }
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
