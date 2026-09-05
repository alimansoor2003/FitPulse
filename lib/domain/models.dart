/// Aggregated read models used by the dashboard and history screens.
class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.dayIndex,
    required this.startedAt,
    required this.finishedAt,
    required this.volumeKg,
    required this.completedSets,
  });

  final int id;
  final int dayIndex;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final double volumeKg;
  final int completedSets;

  bool get isActive => finishedAt == null;

  Duration get duration => (finishedAt ?? DateTime.now()).difference(startedAt);
}

/// One point on an exercise progression chart.
class ProgressPoint {
  const ProgressPoint({
    required this.date,
    required this.estimatedOneRm,
    required this.topWeightKg,
    required this.volumeKg,
  });

  final DateTime date;
  final double estimatedOneRm;
  final double topWeightKg;
  final double volumeKg;
}

/// Sets performed in a given week, for the consistency strip.
class WeeklyLoad {
  const WeeklyLoad({
    required this.weekStart,
    required this.sessions,
    required this.volumeKg,
  });

  final DateTime weekStart;
  final int sessions;
  final double volumeKg;
}

/// The previous performance for one set slot, shown as a ghost hint.
class GhostSet {
  const GhostSet({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;
}

/// Everything the dashboard header needs, derived from session summaries.
class DashboardStats {
  const DashboardStats({
    required this.sessionsThisWeek,
    required this.weeklyGoal,
    required this.volumeThisWeekKg,
    required this.totalSessions,
    required this.totalVolumeKg,
    required this.streakWeeks,
    required this.completedSets,
    this.lastSession,
  });

  final int sessionsThisWeek;
  final int weeklyGoal;
  final double volumeThisWeekKg;
  final int totalSessions;
  final double totalVolumeKg;
  final int streakWeeks;
  final int completedSets;
  final SessionSummary? lastSession;

  double get weeklyProgress =>
      weeklyGoal == 0 ? 0 : (sessionsThisWeek / weeklyGoal).clamp(0.0, 1.0);

  static const DashboardStats empty = DashboardStats(
    sessionsThisWeek: 0,
    weeklyGoal: 3,
    volumeThisWeekKg: 0,
    totalSessions: 0,
    totalVolumeKg: 0,
    streakWeeks: 0,
    completedSets: 0,
  );
}
