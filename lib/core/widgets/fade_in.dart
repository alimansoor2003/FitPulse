import 'package:flutter/material.dart';

/// Staggered fade + rise used for screen entrances.
class FadeIn extends StatefulWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
    this.duration = const Duration(milliseconds: 480),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
