import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });

  final String userName;
  final bool onboarded;
  final int defaultRestSeconds;
  final bool autoStartRest;
  final bool showArabicNames;
  final double weightStep;
  final int weeklyGoal;

  static const AppSettings fallback = AppSettings(
    userName: 'Athlete',
    onboarded: false,
    defaultRestSeconds: 90,
    autoStartRest: true,
    showArabicNames: true,
    weightStep: 2.5,
    weeklyGoal: 3,
  );

  AppSettings copyWith({
    String? userName,
    bool? onboarded,
    int? defaultRestSeconds,
    bool? autoStartRest,
    bool? showArabicNames,
    double? weightStep,
    int? weeklyGoal,
  }) {
    return AppSettings(
      userName: userName ?? this.userName,
      onboarded: onboarded ?? this.onboarded,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      autoStartRest: autoStartRest ?? this.autoStartRest,
      showArabicNames: showArabicNames ?? this.showArabicNames,
      weightStep: weightStep ?? this.weightStep,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
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
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
