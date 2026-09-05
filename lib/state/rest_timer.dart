import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RestTimerState {
  const RestTimerState({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.isRunning,
    required this.label,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final bool isRunning;
  final String label;

  static const RestTimerState idle = RestTimerState(
    remainingSeconds: 0,
    totalSeconds: 0,
    isRunning: false,
    label: '',
  );

  bool get isActive => isRunning && remainingSeconds > 0;

  /// 1.0 at the start of the rest period, 0.0 when it elapses.
  double get progress =>
      totalSeconds == 0 ? 0 : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);

  RestTimerState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    bool? isRunning,
    String? label,
  }) {
    return RestTimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      isRunning: isRunning ?? this.isRunning,
      label: label ?? this.label,
    );
  }
}

/// Drives the between-sets rest countdown shown as a bar above the
/// workout screen's action button.
class RestTimerController extends Notifier<RestTimerState> {
  Timer? _timer;

  @override
  RestTimerState build() {
    ref.onDispose(() => _timer?.cancel());
    return RestTimerState.idle;
  }

  void start(int seconds, {String label = 'Rest'}) {
    _timer?.cancel();
    if (seconds <= 0) {
      state = RestTimerState.idle;
      return;
    }
    state = RestTimerState(
      remainingSeconds: seconds,
      totalSeconds: seconds,
      isRunning: true,
      label: label,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final int next = state.remainingSeconds - 1;
    if (next <= 0) {
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(remainingSeconds: 0, isRunning: false);
      HapticFeedback.heavyImpact();
      return;
    }
    state = state.copyWith(remainingSeconds: next);
  }

  void addSeconds(int seconds) {
    if (state.remainingSeconds <= 0) {
      // Idle or already elapsed - nothing to extend, so start fresh.
      start(seconds, label: state.label.isEmpty ? 'Rest' : state.label);
      return;
    }
    // Running or paused with time left: add to what remains without
    // touching isRunning, so a paused timer stays paused.
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds + seconds,
      totalSeconds: state.totalSeconds + seconds,
    );
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isRunning: false);
  }

  void resume() {
    if (state.remainingSeconds <= 0 || state.isRunning) return;
    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = RestTimerState.idle;
  }
}

final NotifierProvider<RestTimerController, RestTimerState> restTimerProvider =
    NotifierProvider<RestTimerController, RestTimerState>(
  RestTimerController.new,
);
