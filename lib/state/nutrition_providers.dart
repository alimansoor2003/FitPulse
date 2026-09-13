import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/nutrition_repository.dart';
import '../data/services/gemini_food_service.dart';
import '../domain/nutrition.dart';
import 'providers.dart';
import 'settings_controller.dart';

final Provider<NutritionRepository> nutritionRepositoryProvider =
    Provider<NutritionRepository>(
  (ref) => NutritionRepository(ref.watch(databaseProvider)),
);

/// Owns the HTTP client behind the parser, so its connection pool is closed
/// with the provider container rather than leaking for the app's lifetime.
final Provider<GeminiFoodService> geminiFoodServiceProvider =
    Provider<GeminiFoodService>((ref) {
  final GeminiFoodService service = GeminiFoodService();
  ref.onDispose(service.dispose);
  return service;
});

/// The clock. Injectable so the midnight rollover is testable without
/// actually waiting for midnight.
final Provider<DateTime Function()> nowProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Midnight at the start of the current day, re-emitted when the day turns
/// over.
///
/// A Drift query resolves its date window once, when the stream is created.
/// The nutrition card lives on the Today screen, which stays mounted for as
/// long as the app is open, so that window used to stay pinned to whichever
/// day the app was launched on: food logged after midnight fell outside it
/// and the card kept showing yesterday's items. Anything scoped to "today"
/// watches this instead, so the query is rebuilt against the new day.
class CurrentDay extends Notifier<DateTime> {
  Timer? _rollover;

  @override
  DateTime build() {
    final _ResumeObserver observer = _ResumeObserver(refresh);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      _rollover?.cancel();
      _rollover = null;
      WidgetsBinding.instance.removeObserver(observer);
    });
    _scheduleRollover();
    return _startOfDay();
  }

  DateTime _startOfDay() {
    final DateTime now = ref.read(nowProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  /// Wakes just after the next midnight, for the app being left open across
  /// the boundary.
  void _scheduleRollover() {
    _rollover?.cancel();
    final DateTime now = ref.read(nowProvider)();
    // DateTime normalises a day past the end of the month, so this is still
    // the next midnight on the 31st and on New Year's Eve. Doing the maths on
    // local wall-clock time also survives a DST shift, where the gap to
    // midnight is 23 or 25 hours rather than 24.
    final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _rollover = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      refresh,
    );
  }

  /// Re-reads the clock and reschedules.
  ///
  /// Called at midnight and on every resume. The resume path is the one that
  /// matters most: a sleeping phone does not run the timer on time, and the
  /// ordinary case is logging dinner, sleeping, and opening the app the next
  /// morning.
  void refresh() {
    final DateTime today = _startOfDay();
    if (today != state) state = today;
    _scheduleRollover();
  }
}

final NotifierProvider<CurrentDay, DateTime> currentDayProvider =
    NotifierProvider<CurrentDay, DateTime>(CurrentDay.new);

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResumed);

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

/// Everything logged today, newest write last.
///
/// Keyed on [currentDayProvider], so the window follows the calendar instead
/// of being frozen at subscription time.
final StreamProvider<List<FoodLog>> todayFoodLogsProvider =
    StreamProvider<List<FoodLog>>((ref) {
  final DateTime day = ref.watch(currentDayProvider);
  return ref.watch(nutritionRepositoryProvider).watchFoodLogsForDay(day);
});

/// Today's totals. Derived rather than queried so the card never shows a
/// loading state once the stream has emitted once.
final Provider<DailyMacros> todayMacrosProvider = Provider<DailyMacros>((ref) {
  final AsyncValue<List<FoodLog>> logs = ref.watch(todayFoodLogsProvider);
  return logs.maybeWhen(
    data: (List<FoodLog> rows) =>
        ref.watch(nutritionRepositoryProvider).macrosFrom(rows),
    orElse: () => DailyMacros.empty,
  );
});

// --------------------------------------------------------------- controller

/// The logger's phases. [FoodLogController] moves through
/// idle -> (AsyncLoading) -> review -> submitted, with failures surfacing as
/// [AsyncError] so the sheet can offer Retry and manual entry side by side.
sealed class FoodLogState {
  const FoodLogState();
}

class FoodLogIdle extends FoodLogState {
  const FoodLogIdle();
}

/// Parsed items awaiting the user's review. The sheet takes a working copy of
/// [items]; this list is the un-edited result the parser returned.
class FoodLogReview extends FoodLogState {
  const FoodLogReview(this.items);

  final List<ParsedFood> items;
}

class FoodLogSubmitted extends FoodLogState {
  const FoodLogSubmitted(this.count);

  /// How many items were written, for the confirmation line.
  final int count;
}

/// Auto-disposed: the logger sheet is its only listener, so closing the sheet
/// throws the draft away and the next one opens at [FoodLogIdle] without any
/// manual reset.
class FoodLogController extends AutoDisposeAsyncNotifier<FoodLogState> {
  /// True once the sheet has closed. Every `state =` that follows an `await`
  /// is guarded by it: swiping the sheet away mid-request disposes the
  /// notifier while the HTTP call is still in flight, and assigning to a
  /// disposed notifier throws.
  bool _disposed = false;

  /// Returns synchronously so the sheet's first frame is [FoodLogIdle] rather
  /// than a loading spinner.
  @override
  FutureOr<FoodLogState> build() {
    ref.onDispose(() => _disposed = true);
    return const FoodLogIdle();
  }

  /// Sends [description] to Gemini and moves to the review phase.
  ///
  /// Failures land in [AsyncError] carrying a [FoodParseException], which is
  /// the only error type the sheet has to know how to render.
  Future<void> parse(String description, {required MealType defaultMeal}) async {
    final AppSettings settings = ref.read(settingsProvider);
    state = const AsyncValue<FoodLogState>.loading();

    try {
      final List<ParsedFood> items =
          await ref.read(geminiFoodServiceProvider).parseMeal(
                description,
                apiKey: settings.effectiveGeminiKey,
                defaultMeal: defaultMeal,
              );
      if (_disposed) return;
      state = AsyncValue<FoodLogState>.data(FoodLogReview(items));
    } on FoodParseException catch (error, stack) {
      if (_disposed) return;
      state = AsyncValue<FoodLogState>.error(error, stack);
    } catch (error, stack) {
      if (_disposed) return;
      // Anything unexpected is still shown as one readable line rather than
      // as a raw exception string.
      state = AsyncValue<FoodLogState>.error(
        FoodParseException('Something went wrong: $error'),
        stack,
      );
    }
  }

  /// Skips the AI entirely - used by the manual-entry fallback so the same
  /// review UI handles both paths.
  void review(List<ParsedFood> items) {
    state = AsyncValue<FoodLogState>.data(FoodLogReview(items));
  }

  /// Writes the reviewed items in one batch. The home gauges update through
  /// [todayFoodLogsProvider]'s existing Drift stream - nothing is invalidated
  /// by hand.
  Future<void> submit(List<ParsedFood> items) async {
    final List<ParsedFood> keep = items
        .where((ParsedFood item) => item.name.trim().isNotEmpty)
        .toList(growable: false);
    if (keep.isEmpty) {
      state = const AsyncValue<FoodLogState>.data(FoodLogSubmitted(0));
      return;
    }
    await ref.read(nutritionRepositoryProvider).logMeal(keep);
    if (_disposed) return;
    state = AsyncValue<FoodLogState>.data(FoodLogSubmitted(keep.length));
  }

  /// Back to the input step, used by "start over" after a failed parse.
  void reset() {
    state = const AsyncValue<FoodLogState>.data(FoodLogIdle());
  }
}

final AutoDisposeAsyncNotifierProvider<FoodLogController, FoodLogState>
    foodLogControllerProvider =
    AutoDisposeAsyncNotifierProvider<FoodLogController, FoodLogState>(
  FoodLogController.new,
);
