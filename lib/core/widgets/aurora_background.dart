import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The ambient neon glow that sits behind every screen. Painted with plain
/// radial gradients (no blur filters) so it stays cheap on mid-range Androids.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
  });

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.screenGradient),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -160,
            right: -110,
            child: _Glow(
              size: 380,
              color: AppColors.neonBlue.withOpacity(0.34 * intensity),
            ),
          ),
          Positioned(
            top: 190,
            left: -150,
            child: _Glow(
              size: 320,
              color: AppColors.neonCyan.withOpacity(0.18 * intensity),
            ),
          ),
          Positioned(
            bottom: -170,
            right: -80,
            child: _Glow(
              size: 360,
              color: AppColors.neonBlue.withOpacity(0.20 * intensity),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withOpacity(0), Colors.transparent],
            stops: const <double>[0.0, 0.72, 1.0],
          ),
        ),
      ),
    );
  }
}
