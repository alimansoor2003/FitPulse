import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../state/settings_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    await ref.read(settingsProvider.notifier).completeOnboarding(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: <Widget>[
                    const _Wordmark(),
                    const Spacer(),
                    Text('v1.0', style: AppText.caption),
                  ],
                ),
              ),
              const Expanded(child: Center(child: _PulseHero())),
              FadeIn(
                delay: const Duration(milliseconds: 180),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16 + MediaQuery.viewInsetsOf(context).bottom * 0.2,
                  ),
                  child: GlassCard(
                    radius: 30,
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                    highlighted: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          'Train for\nFitness Success',
                          style: AppText.display,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Log every set, beat your last numbers, and let '
                          'progressive overload do the rest. Everything stays '
                          'on your phone.',
                          style: AppText.body,
                        ),
                        const SizedBox(height: 22),
                        _NameField(controller: _name),
                        const SizedBox(height: 18),
                        NeonButton(
                          label: 'GET STARTED',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _start,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _start,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: Text(
                              'Skip for now',
                              style: sora(13, 500,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: sora(15, 600),
        cursorColor: AppColors.neonCyan,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.neonCyan,
            size: 20,
          ),
          hintText: 'What should we call you?',
          hintStyle: sora(14, 400, color: AppColors.textTertiary),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.neonBlue.withOpacity(0.5),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text('FitPulse', style: sora(19, 700, letterSpacing: -0.4)),
      ],
    );
  }
}

/// Photo-free hero: concentric neon rings with a pulsing core.
class _PulseHero extends StatefulWidget {
  const _PulseHero();

  @override
  State<_PulseHero> createState() => _PulseHeroState();
}

class _PulseHeroState extends State<_PulseHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: const Size(280, 280),
          painter: _PulsePainter(_controller.value),
          child: const SizedBox(
            width: 280,
            height: 280,
            child: Center(
              child: Icon(
                Icons.fitness_center_rounded,
                size: 54,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.shortestSide / 2;

    // Expanding pulse rings.
    for (int i = 0; i < 3; i++) {
      final double phase = (t + i / 3) % 1.0;
      final double radius = maxRadius * (0.35 + phase * 0.65);
      final double opacity = (1 - phase) * 0.35;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.neonCyan.withOpacity(opacity),
      );
    }

    // Static tick ring.
    const int ticks = 60;
    for (int i = 0; i < ticks; i++) {
      final double angle = (math.pi * 2 / ticks) * i;
      final double inner = maxRadius * 0.78;
      final double outer = inner + (i % 5 == 0 ? 12 : 6);
      final Offset p1 =
          center + Offset(math.cos(angle) * inner, math.sin(angle) * inner);
      final Offset p2 =
          center + Offset(math.cos(angle) * outer, math.sin(angle) * outer);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(i % 5 == 0 ? 0.22 : 0.10),
      );
    }

    // Sweeping arc.
    final double sweepStart = t * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * 0.78),
      sweepStart,
      math.pi / 2.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: <Color>[AppColors.neonBlue, AppColors.neonCyan],
        ).createShader(
          Rect.fromCircle(center: center, radius: maxRadius),
        ),
    );

    // Core glow.
    canvas.drawCircle(
      center,
      maxRadius * 0.30,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.neonBlue.withOpacity(0.55),
            AppColors.neonBlue.withOpacity(0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: maxRadius * 0.30),
        ),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}
