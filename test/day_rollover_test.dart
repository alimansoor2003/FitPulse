import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitpulse/data/db/app_database.dart';
import 'package:fitpulse/data/repositories/nutrition_repository.dart';
import 'package:fitpulse/state/nutrition_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records which day each subscription asked for, and answers without ever
/// reaching SQLite.
class _RecordingRepository extends NutritionRepository {
  _RecordingRepository()
      : super(AppDatabase.withExecutor(NativeDatabase.memory()));

  final List<DateTime> daysRequested = <DateTime>[];

  @override
  Stream<List<FoodLog>> watchFoodLogsForDay(DateTime day) {
    daysRequested.add(day);
    return Stream<List<FoodLog>>.value(const <FoodLog>[]);
  }
}

/// Regression tests for "I log food after midnight and it still shows
/// yesterday".
///
/// A Drift stream resolves its date window when it is created. The Today
/// screen never unmounts, so the window used to stay pinned to the day the
/// app was launched: rows written after midnight fell outside it and were
/// invisible, while the previous day's rows kept matching and kept showing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Each test builds its own throwaway AppDatabase purely to satisfy the
  // repository's constructor; no query ever runs against it.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late DateTime fakeNow;

  ProviderContainer containerAt(DateTime start, _RecordingRepository repo) {
    fakeNow = start;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        nowProvider.overrideWithValue(() => fakeNow),
        nutritionRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the current day starts on the day the app was opened', () {
    final ProviderContainer container =
        containerAt(DateTime(2026, 9, 13, 22, 30), _RecordingRepository());

    expect(container.read(currentDayProvider), DateTime(2026, 9, 13));
  });

  test('crossing midnight moves the day forward', () {
    final ProviderContainer container =
        containerAt(DateTime(2026, 9, 13, 23, 59), _RecordingRepository());
    expect(container.read(currentDayProvider), DateTime(2026, 9, 13));

    // 00:15 the next morning - the moment the bug used to bite.
    fakeNow = DateTime(2026, 9, 14, 0, 15);
    container.read(currentDayProvider.notifier).refresh();

    expect(container.read(currentDayProvider), DateTime(2026, 9, 14));
  });

  test('the food query is re-subscribed against the new day', () async {
    final _RecordingRepository repo = _RecordingRepository();
    final ProviderContainer container =
        containerAt(DateTime(2026, 9, 13, 23, 59), repo);

    // Hold a listener so the stream provider stays alive, like the Today
    // screen does.
    container.listen(todayFoodLogsProvider, (_, __) {}, fireImmediately: true);
    await container.read(todayFoodLogsProvider.future);
    expect(repo.daysRequested, <DateTime>[DateTime(2026, 9, 13)]);

    fakeNow = DateTime(2026, 9, 14, 0, 15);
    container.read(currentDayProvider.notifier).refresh();
    await container.read(todayFoodLogsProvider.future);

    expect(
      repo.daysRequested,
      <DateTime>[DateTime(2026, 9, 13), DateTime(2026, 9, 14)],
      reason: 'the window must follow the calendar, not the subscription',
    );
  });

  test('a refresh inside the same day does not churn the query', () async {
    final _RecordingRepository repo = _RecordingRepository();
    final ProviderContainer container =
        containerAt(DateTime(2026, 9, 13, 9, 0), repo);

    container.listen(todayFoodLogsProvider, (_, __) {}, fireImmediately: true);
    await container.read(todayFoodLogsProvider.future);

    fakeNow = DateTime(2026, 9, 13, 18, 0);
    container.read(currentDayProvider.notifier).refresh();
    await container.read(todayFoodLogsProvider.future);

    expect(repo.daysRequested, hasLength(1),
        reason: 'resuming mid-day must not tear down a healthy stream');
  });

  test('the day rolls over correctly at a month boundary', () {
    final ProviderContainer container =
        containerAt(DateTime(2026, 9, 30, 23, 59), _RecordingRepository());

    fakeNow = DateTime(2026, 10, 1, 0, 5);
    container.read(currentDayProvider.notifier).refresh();

    expect(container.read(currentDayProvider), DateTime(2026, 10, 1));
  });

  test('coming back to the foreground re-checks the date', () async {
    final _RecordingRepository repo = _RecordingRepository();
    final ProviderContainer container =
        containerAt(DateTime(2026, 9, 13, 23, 50), repo);
    container.listen(todayFoodLogsProvider, (_, __) {}, fireImmediately: true);
    await container.read(todayFoodLogsProvider.future);

    // The phone sleeps through midnight, so the rollover timer never runs on
    // time. Resuming has to notice on its own - this is the common path:
    // log dinner, sleep, open the app the next morning.
    fakeNow = DateTime(2026, 9, 14, 7, 30);
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    WidgetsBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await container.read(todayFoodLogsProvider.future);

    expect(container.read(currentDayProvider), DateTime(2026, 9, 14));
    expect(
      repo.daysRequested,
      <DateTime>[DateTime(2026, 9, 13), DateTime(2026, 9, 14)],
      reason: 'resuming after midnight must re-query for the new day',
    );
  });
}
