import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/data/repositories/hydration_repository.dart';
import 'package:fitpulse/domain/hydration.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late HydrationRepository repo;

  setUp(() {
    repo = HydrationRepository(
      AppDatabase.withExecutor(NativeDatabase.memory()),
    );
  });

  int nextId = 1;
  WaterLog drink(DateTime at, int ml, {int? id}) =>
      WaterLog(id: id ?? nextId++, amountMl: ml, loggedAt: at);

  group('formatWaterMl', () {
    test('stays in millilitres below a litre', () {
      expect(formatWaterMl(0), '0 ml');
      expect(formatWaterMl(250), '250 ml');
      expect(formatWaterMl(999), '999 ml');
    });

    test('switches to litres and trims trailing zeros', () {
      expect(formatWaterMl(1000), '1 L');
      expect(formatWaterMl(1500), '1.5 L');
      expect(formatWaterMl(1250), '1.25 L');
      expect(formatWaterMl(2500), '2.5 L');
    });
  });

  group('waterPresetsFrom', () {
    test('defaults when nothing has been saved', () {
      expect(waterPresetsFrom(null), kDefaultWaterPresetsMl);
    });

    test('restores saved amounts', () {
      expect(waterPresetsFrom(<String>['330', '1000']), <int>[330, 1000]);
    });

    test('falls back per slot, keeping the good one', () {
      expect(waterPresetsFrom(<String>['abc', '750']), <int>[250, 750]);
      expect(waterPresetsFrom(<String>['9000', '750']), <int>[250, 750]);
      expect(waterPresetsFrom(<String>['5', '750']), <int>[250, 750]);
      expect(waterPresetsFrom(<String>['330']), <int>[330, 500]);
    });
  });

  group('todayFrom', () {
    test('an empty day has nothing to undo', () {
      final HydrationToday today = repo.todayFrom(<WaterLog>[]);
      expect(today.totalMl, 0);
      expect(today.canUndo, isFalse);
    });

    test('sums the day and points undo at the most recent drink', () {
      final HydrationToday today = repo.todayFrom(<WaterLog>[
        drink(DateTime(2026, 9, 16, 8), 250, id: 1),
        drink(DateTime(2026, 9, 16, 12), 500, id: 2),
        drink(DateTime(2026, 9, 16, 10), 330, id: 3),
      ]);

      expect(today.totalMl, 1080);
      expect(today.drinkCount, 3);
      expect(today.lastDrinkId, 2, reason: 'latest by time, not by id');
      expect(today.lastDrinkMl, 500);
    });

    test('two drinks in the same instant undo the newer row first', () {
      final DateTime same = DateTime(2026, 9, 16, 9);
      final HydrationToday today = repo.todayFrom(<WaterLog>[
        drink(same, 250, id: 7),
        drink(same, 500, id: 8),
      ]);
      expect(today.lastDrinkId, 8);
    });

    test('progress is clamped so an over-goal day fills the ring', () {
      final HydrationToday today = repo.todayFrom(<WaterLog>[
        drink(DateTime(2026, 9, 16, 9), 3000),
      ]);
      expect(today.progressToward(2500), 1.0);
      expect(today.progressToward(6000), 0.5);
    });
  });

  group('trendFrom', () {
    test('one row per calendar day, oldest first, gaps included', () {
      final HydrationTrend trend = repo.trendFrom(
        <WaterLog>[drink(DateTime(2026, 9, 16, 9), 500)],
        from: DateTime(2026, 9, 10),
        days: 7,
        goalMl: 2500,
      );

      expect(trend.days, hasLength(7));
      expect(trend.days.first.day, DateTime(2026, 9, 10));
      expect(trend.days.last.day, DateTime(2026, 9, 16));
      expect(trend.days.last.totalMl, 500);
      expect(trend.days.first.isLogged, isFalse);
    });

    test('averages over logged days and counts days on goal', () {
      final HydrationTrend trend = repo.trendFrom(
        <WaterLog>[
          drink(DateTime(2026, 9, 14, 9), 1500),
          drink(DateTime(2026, 9, 14, 15), 1500), // 3000: on goal
          drink(DateTime(2026, 9, 16, 9), 1000), // 1000: under
        ],
        from: DateTime(2026, 9, 10),
        days: 7,
        goalMl: 2500,
      );

      expect(trend.daysLogged, 2);
      expect(trend.averageMl, 2000, reason: '4000 over 2 logged days, not 7');
      expect(trend.daysOnGoal, 1);
      expect(trend.peakMl, 3000);
    });

    test('a drink a minute past midnight lands on the new day', () {
      final HydrationTrend trend = repo.trendFrom(
        <WaterLog>[
          drink(DateTime(2026, 9, 15, 23, 59), 250),
          drink(DateTime(2026, 9, 16, 0, 1), 500),
        ],
        from: DateTime(2026, 9, 15),
        days: 2,
        goalMl: 2500,
      );

      expect(trend.days.first.totalMl, 250);
      expect(trend.days.last.totalMl, 500);
    });

    test('an empty window has no average rather than a zero intake', () {
      final HydrationTrend trend = repo.trendFrom(
        <WaterLog>[],
        from: DateTime(2026, 9, 10),
        days: 7,
        goalMl: 2500,
      );
      expect(trend.isEmpty, isTrue);
      expect(trend.days, hasLength(7));
    });
  });

  group('water goal setting', () {
    Future<ProviderContainer> container(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final SharedPreferences instance = await SharedPreferences.getInstance();
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(instance),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('defaults to 2500 ml', () async {
      final ProviderContainer c = await container(<String, Object>{});
      expect(c.read(settingsProvider).waterGoalMl, 2500);
    });

    test('snaps to the 250 ml step, clamps, and persists', () async {
      final ProviderContainer c = await container(<String, Object>{});
      final SettingsController controller = c.read(settingsProvider.notifier);

      await controller.setWaterGoal(3130);
      expect(c.read(settingsProvider).waterGoalMl, 3250);

      await controller.setWaterGoal(100);
      expect(c.read(settingsProvider).waterGoalMl, 500);

      await controller.setWaterGoal(99999);
      expect(c.read(settingsProvider).waterGoalMl, 6000);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('target_water_ml'), 6000);
    });

    test('re-pinning a preset clamps and persists only that slot',
        () async {
      final ProviderContainer c = await container(<String, Object>{});
      final SettingsController controller = c.read(settingsProvider.notifier);

      await controller.setWaterPreset(1, 750);
      expect(c.read(settingsProvider).waterPresetsMl, <int>[250, 750]);

      await controller.setWaterPreset(0, 99999);
      expect(c.read(settingsProvider).waterPresetsMl, <int>[3000, 750]);

      await controller.setWaterPreset(7, 400);
      expect(c.read(settingsProvider).waterPresetsMl, <int>[3000, 750],
          reason: 'an index with no slot is ignored');

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('water_presets_ml'), <String>['3000', '750']);
    });

    test('a saved goal is read back on launch', () async {
      final ProviderContainer c =
          await container(<String, Object>{'target_water_ml': 3000});
      expect(c.read(settingsProvider).waterGoalMl, 3000);
    });
  });
}
