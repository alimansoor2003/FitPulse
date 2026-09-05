import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular progress ring with a gradient sweep and a soft neon halo.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 6,
    this.child,
    this.trackColor = AppColors.glassFillStrong,
    this.duration = const Duration(milliseconds: 650),
  });

  final double value; // 0..1
  final double size;
  final double stroke;
  final Widget? child;
  final Color trackColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animated, Widget? _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: animated,
              stroke: stroke,
              trackColor: trackColor,
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.trackColor,
  });

  final double value;
  final double stroke;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - stroke) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: <Color>[AppColors.neonBlue, AppColors.neonCyan, AppColors.neonBlue],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.neonCyan.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final double sweep = math.pi * 2 * value;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.stroke != stroke || old.trackColor != trackColor;
}
