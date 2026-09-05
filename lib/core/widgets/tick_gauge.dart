import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The signature 270-degree ticked meter from the reference design.
/// Used as the session-completion readout on the workout screen.
class TickGauge extends StatelessWidget {
  const TickGauge({
    super.key,
    required this.value,
    this.size = 190,
    this.ticks = 44,
    this.child,
  });

  final double value; // 0..1
  final double size;
  final int ticks;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animated, Widget? _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _TickGaugePainter(value: animated, ticks: ticks),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _TickGaugePainter extends CustomPainter {
  _TickGaugePainter({required this.value, required this.ticks});

  final double value;
  final int ticks;

  static const double _start = math.pi * 0.75; // 135 degrees
  static const double _sweep = math.pi * 1.5; // 270 degrees

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outer = size.shortestSide / 2;
    final double inner = outer - size.shortestSide * 0.085;
    final int activeCount = (ticks * value).round();

    final Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    for (int i = 0; i < ticks; i++) {
      final double t = ticks == 1 ? 0 : i / (ticks - 1);
      final double angle = _start + _sweep * t;
      final double dx = math.cos(angle);
      final double dy = math.sin(angle);
      final bool active = i < activeCount;

      final Offset p1 = center + Offset(dx * inner, dy * inner);
      final Offset p2 = center + Offset(dx * outer, dy * outer);

      if (active) {
        paint
          ..color = Color.lerp(AppColors.neonBlue, AppColors.neonCyan, t)!
          ..maskFilter = null;
        canvas.drawLine(p1, p2, paint);
      } else {
        paint
          ..color = Colors.white.withOpacity(0.12)
          ..maskFilter = null;
        canvas.drawLine(p1, p2, paint);
      }
    }

    // Leading dot with a halo, like the reference meter.
    if (value > 0) {
      final double angle = _start + _sweep * value;
      final double mid = (inner + outer) / 2;
      final Offset head =
          center + Offset(math.cos(angle) * mid, math.sin(angle) * mid);
      canvas.drawCircle(
        head,
        7,
        Paint()
          ..color = AppColors.neonCyan.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(head, 3.2, Paint()..color = AppColors.neonCyan);
    }
  }

  @override
  bool shouldRepaint(_TickGaugePainter old) =>
      old.value != value || old.ticks != ticks;
}
