import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../state/rest_timer.dart';

/// Countdown bar that slides in above the finish button after a set is ticked.
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RestTimerState timer = ref.watch(restTimerProvider);
    final RestTimerController controller =
        ref.read(restTimerProvider.notifier);

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: timer.remainingSeconds <= 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                opaque: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: AppColors.neonCyan,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Rest - ${timer.label}',
                                overflow: TextOverflow.ellipsis,
                                style: sora(12, 600),
                              ),
                              Text(
                                timer.isRunning ? 'Counting down' : 'Paused',
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatClock(timer.remainingSeconds),
                          style: sora(22, 700, letterSpacing: -0.5),
                        ),
                        const SizedBox(width: 10),
                        _TimerAction(
                          icon: Icons.add_rounded,
                          label: '30s',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.addSeconds(30);
                          },
                        ),
                        const SizedBox(width: 6),
                        _TimerAction(
                          icon: timer.isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (timer.isRunning) {
                              controller.pause();
                            } else {
                              controller.resume();
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        _TimerAction(
                          icon: Icons.close_rounded,
                          onTap: controller.stop,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: timer.progress),
                        duration: const Duration(milliseconds: 400),
                        builder:
                            (BuildContext context, double value, Widget? _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            backgroundColor: Colors.white.withOpacity(0.07),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.neonCyan,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TimerAction extends StatelessWidget {
  const _TimerAction({required this.icon, required this.onTap, this.label});

  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: AppColors.textPrimary),
            if (label != null) ...<Widget>[
              const SizedBox(width: 3),
              Text(label!, style: sora(11, 600)),
            ],
          ],
        ),
      ),
    );
  }
}
