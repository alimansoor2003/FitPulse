import 'package:intl/intl.dart';

String formatWeight(double kg) {
  if (kg <= 0) return '0';
  final bool whole = kg == kg.roundToDouble();
  return whole ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1);
}

/// 12,450 kg -> "12.4k kg"
String formatVolume(double kg) {
  if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}k';
  return kg.toStringAsFixed(0);
}

String formatDuration(Duration d) {
  final int h = d.inHours;
  final int m = d.inMinutes.remainder(60);
  final int s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String formatClock(int seconds) {
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String friendlyDate(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(date.year, date.month, date.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';
  return DateFormat('d MMM').format(date);
}

String shortDate(DateTime date) => DateFormat('d MMM').format(date);

/// Epley formula - the estimated one-rep max for a given set.
double estimatedOneRepMax(double weightKg, int reps) {
  if (weightKg <= 0 || reps <= 0) return 0;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30.0);
}

/// Monday of the week containing [date].
DateTime startOfWeek(DateTime date) {
  final DateTime d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}
