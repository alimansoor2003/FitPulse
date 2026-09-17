import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/day_tracker.dart';
import '../../../state/day_tracker_providers.dart';

/// Ring colour for protein and water.
const Color kFuelRingColor = AppColors.neonCyan;

/// Ring colour for training.
const Color kWorkoutRingColor = AppColors.neonGreen;

const List<String> _weekdays = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

/// A glance at the days around today: each past day and today carries two
/// small rings, food & water and workout. Nothing here is tappable.
class DayTrackerStrip extends ConsumerWidget {
  const DayTrackerStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<DayMark> marks = ref.watch(dayTrackProvider);
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final DayMark mark in marks)
              Expanded(child: _DayColumn(mark: mark)),
          ],
        ),
        const SizedBox(height: 14),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 6,
          children: <Widget>[
            _Legend(color: kFuelRingColor, label: 'Food & water'),
            _Legend(color: kWorkoutRingColor, label: 'Workout'),
          ],
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.mark});

  final DayMark mark;

  String get _semantics {
    final String name = '${_weekdays[mark.day.weekday - 1]} ${mark.day.day}';
    if (mark.isFuture) return name;
    final String fuel = mark.fuelDone
        ? 'food and water done'
        : 'food and water ${(mark.fuel * 100).round()} percent';
    final String workout = mark.workoutDone ? 'workout done' : 'no workout';
    return '${mark.isToday ? 'Today, ' : ''}$name: $fuel, $workout';
  }

  @override
  Widget build(BuildContext context) {
    final bool today = mark.isToday;
    final Color numberColor = mark.isFuture
        ? AppColors.textTertiary
        : AppColors.textPrimary;

    return Semantics(
      label: _semantics,
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          Text(
            _weekdays[mark.day.weekday - 1],
            maxLines: 1,
            style: today
                ? sora(11, 600, color: AppColors.neonCyan, letterSpacing: 0.3)
                : AppText.caption,
          ),
          const SizedBox(height: 7),
          Container(
            width: 40,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: today ? AppColors.accentGradient : null,
              color: today
                  ? null
                  : mark.isFuture
                      ? Colors.transparent
                      : AppColors.glassFill,
              borderRadius: BorderRadius.circular(20),
              border: today
                  ? null
                  : Border.all(
                      color: mark.isFuture
                          ? AppColors.glassBorder
                          : AppColors.glassBorderBright,
                    ),
              boxShadow: today
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.45),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${mark.day.day}',
                maxLines: 1,
                style: sora(15, today ? 700 : 600, color: numberColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: mark.isFuture ? 0.35 : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _MiniRing(value: mark.fuel, color: kFuelRingColor),
                const SizedBox(width: 3),
                _MiniRing(value: mark.workout, color: kWorkoutRingColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 13px progress ring in one accent colour. A finished ring gets a faint
/// glow so a completed day reads at a glance.
class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animated, Widget? _) {
        return CustomPaint(
          size: const Size.square(13),
          painter: _MiniRingPainter(value: animated, color: color),
        );
      },
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  _MiniRingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  static const double _stroke = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - _stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.glassFillStrong,
    );
    if (value <= 0) return;

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (value >= 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = color.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) =>
      old.value != value || old.color != color;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MiniRing(value: 1, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppText.caption),
      ],
    );
  }
}
