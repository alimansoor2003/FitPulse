import 'package:fitpulse/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatWeight', () {
    test('drops the decimal for whole numbers', () {
      expect(formatWeight(40), '40');
      expect(formatWeight(0), '0');
    });

    test('keeps one decimal for plates', () {
      expect(formatWeight(42.5), '42.5');
    });
  });

  group('formatVolume', () {
    test('abbreviates thousands', () {
      expect(formatVolume(12500), '12.5k');
      expect(formatVolume(880), '880');
    });
  });

  group('formatClock', () {
    test('pads to mm:ss', () {
      expect(formatClock(90), '01:30');
      expect(formatClock(5), '00:05');
    });
  });

  group('estimatedOneRepMax', () {
    test('returns the load itself for a single', () {
      expect(estimatedOneRepMax(100, 1), 100);
    });

    test('applies the Epley formula above one rep', () {
      expect(estimatedOneRepMax(60, 10), closeTo(80, 0.001));
    });

    test('is zero for an unlogged set', () {
      expect(estimatedOneRepMax(0, 0), 0);
    });
  });

  group('startOfWeek', () {
    test('snaps back to the Monday of that week', () {
      final DateTime date = DateTime(2026, 9, 4);
      final DateTime monday = startOfWeek(date);
      expect(monday.weekday, DateTime.monday);
      expect(monday.isAfter(date), isFalse);
      expect(date.difference(monday).inDays, lessThan(7));
    });

    test('is idempotent', () {
      final DateTime first = startOfWeek(DateTime(2026, 9, 4, 22, 15));
      expect(startOfWeek(first), first);
    });
  });
}
