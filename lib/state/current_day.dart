import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The clock. Injectable so the midnight rollover is testable without
/// actually waiting for midnight.
final Provider<DateTime Function()> nowProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Midnight at the start of the current day, re-emitted when the day turns
/// over.
///
/// A Drift query resolves its date window once, when the stream is created.
/// The nutrition and hydration cards live on the Today screen, which stays
/// mounted for as long as the app is open, so that window used to stay pinned
/// to whichever day the app was launched on: food logged after midnight fell
/// outside it and the card kept showing yesterday's items. Anything scoped to
/// "today" watches this instead, so the query is rebuilt against the new day.
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
