import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../domain/hydration.dart';
import '../../../state/hydration_providers.dart';
import '../../../state/settings_controller.dart';
import '../custom_water_sheet.dart';

/// Today's water intake with one-tap logging, on the Today screen.
///
/// Mirrors the nutrition card's rhythm - ring on the left, figures on the
/// right, actions underneath - so the two read as a pair.
class HydrationCard extends ConsumerWidget {
  const HydrationCard({super.key});

  Future<void> _add(WidgetRef ref, int ml, {required int goalMl}) async {
    final HydrationToday before = ref.read(todayHydrationProvider);
    await ref.read(hydrationRepositoryProvider).logDrink(ml);

    // A heavier tap for the drink that crosses the goal, so reaching it is
    // felt as well as seen.
    final bool crossedGoal =
        before.totalMl < goalMl && before.totalMl + ml >= goalMl;
    if (crossedGoal) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _addCustom(
    BuildContext context,
    WidgetRef ref, {
    required int goalMl,
  }) async {
    final int? ml = await showCustomWaterSheet(context);
    if (ml == null) return;
    await _add(ref, ml, goalMl: goalMl);
  }

  /// Opens a pinned slot for editing and saves what the user settles on.
  /// Editing never logs a drink.
  Future<void> _editPreset(
    BuildContext context,
    WidgetRef ref, {
    required int index,
    required int currentMl,
  }) async {
    final String label = kWaterPresetLabels[index];
    final int? ml = await showCustomWaterSheet(
      context,
      title: 'Edit $label',
      subtitle: 'Tapping $label will log this amount. Hold it for 2.5 s to '
          'change it again.',
      confirmVerb: 'SAVE',
      initialMl: currentMl,
    );
    if (ml == null || ml == currentMl) return;
    await ref.read(settingsProvider.notifier).setWaterPreset(index, ml);
    HapticFeedback.mediumImpact();
  }

  Future<void> _undo(WidgetRef ref, HydrationToday today) async {
    final int? id = today.lastDrinkId;
    if (id == null) return;
    await ref.read(hydrationRepositoryProvider).deleteWaterLog(id);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HydrationToday today = ref.watch(todayHydrationProvider);
    final int goalMl =
        ref.watch(settingsProvider.select((AppSettings s) => s.waterGoalMl));
    final List<int> presets = ref.watch(
      settingsProvider.select((AppSettings s) => s.waterPresetsMl),
    );

    final double progress = today.progressToward(goalMl);
    final int remaining = goalMl - today.totalMl;
    final bool reached = remaining <= 0;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ProgressRing(
                value: progress,
                size: 86,
                stroke: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.water_drop_rounded,
                      size: 18,
                      color: reached
                          ? AppColors.neonGreen
                          : AppColors.neonCyan,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(progress * 100).round()}%',
                      style: sora(14, 700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Scales down rather than overflowing if a big total
                    // meets a large system text scale.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatWaterMl(today.totalMl),
                        style: AppText.metric,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${formatWaterMl(goalMl)} daily goal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        if (reached) ...<Widget>[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.neonGreen,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            reached
                                ? 'Goal reached'
                                : '${formatWaterMl(remaining)} to go',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: sora(
                              12,
                              600,
                              color: reached
                                  ? AppColors.neonGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              for (int i = 0; i < presets.length; i++) ...<Widget>[
                Expanded(
                  child: _PresetButton(
                    icon: i == 0
                        ? Icons.water_drop_outlined
                        : Icons.local_drink_rounded,
                    amount: '+${formatWaterMl(presets[i])}',
                    caption: kWaterPresetLabels[i],
                    onTap: () => _add(ref, presets[i], goalMl: goalMl),
                    onHeld: () => _editPreset(
                      context,
                      ref,
                      index: i,
                      currentMl: presets[i],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _QuickAddButton(
                  icon: Icons.tune_rounded,
                  amount: 'Custom',
                  caption: 'Any amount',
                  onTap: () => _addCustom(context, ref, goalMl: goalMl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  today.drinkCount == 0
                      ? 'Hold Glass or Bottle to change its amount'
                      : '${today.drinkCount} '
                          'drink${today.drinkCount == 1 ? '' : 's'} today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
              if (today.canUndo)
                _UndoButton(
                  label: 'Undo ${formatWaterMl(today.lastDrinkMl ?? 0)}',
                  onTap: () => _undo(ref, today),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pinned quick-add slot: tap to log, hold for [kPresetHoldDuration] to
/// edit what it logs.
///
/// Three outcomes, decided on release:
///   - a quick tap logs the drink, as before;
///   - holding to the end opens the editor, and the release logs nothing;
///   - letting go part-way through a visible hold cancels. Someone who
///     started holding and changed their mind should not get a drink logged
///     for their trouble.
///
/// The fill that rises through the tile is driven by one AnimationController
/// wrapped around only the overlay, so the hold costs a single repaint of a
/// plain colour per frame - no blur, no layout.
class _PresetButton extends StatefulWidget {
  const _PresetButton({
    required this.icon,
    required this.amount,
    required this.caption,
    required this.onTap,
    required this.onHeld,
  });

  final IconData icon;
  final String amount;
  final String caption;
  final VoidCallback onTap;
  final VoidCallback onHeld;

  @override
  State<_PresetButton> createState() => _PresetButtonState();
}

class _PresetButtonState extends State<_PresetButton>
    with SingleTickerProviderStateMixin {
  /// Past this, a release is a cancelled hold rather than a tap.
  static const Duration _tapCeiling = Duration(milliseconds: 400);

  late final AnimationController _hold =
      AnimationController(vsync: this, duration: kPresetHoldDuration)
        ..addStatusListener(_onHoldStatus);

  bool _pressed = false;
  bool _completed = false;
  bool _signalledHold = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  double get _tapCeilingFraction =>
      _tapCeiling.inMilliseconds / kPresetHoldDuration.inMilliseconds;

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed) return;
    _completed = true;
    HapticFeedback.heavyImpact();
    // Opened after the frame rather than from inside the ticker callback, so
    // pushing the sheet's route never lands mid-frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onHeld();
    });
  }

  void _down() {
    _completed = false;
    _signalledHold = false;
    setState(() => _pressed = true);
    _hold.forward(from: 0);
    _hold.addListener(_maybeSignalHold);
  }

  /// A light tick the moment a press stops being a tap, so the user knows the
  /// hold has started and that letting go now will cancel.
  void _maybeSignalHold() {
    if (_signalledHold || _hold.value < _tapCeilingFraction) return;
    _signalledHold = true;
    HapticFeedback.selectionClick();
  }

  void _release({required bool cancelled}) {
    _hold.removeListener(_maybeSignalHold);
    final bool wasTap = !_completed && _hold.value < _tapCeilingFraction;
    _hold.stop();
    _hold.animateBack(0, duration: const Duration(milliseconds: 180));
    if (mounted) setState(() => _pressed = false);
    if (!cancelled && wasTap) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _release(cancelled: false),
      // Fires when the press turns into a scroll: never log, never edit.
      onTapCancel: () => _release(cancelled: true),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.neonCyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neonCyan.withOpacity(0.22)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _hold,
                    builder: (BuildContext context, Widget? _) {
                      // Nothing to paint during an ordinary tap.
                      if (_hold.value < _tapCeilingFraction) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: _hold.value,
                          widthFactor: 1,
                          child: const ColoredBox(color: Color(0x3300E5FF)),
                        ),
                      );
                    },
                  ),
                ),
                _QuickAddContent(
                  icon: widget.icon,
                  amount: widget.amount,
                  caption: widget.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.icon,
    required this.amount,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final String amount;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.neonCyan.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neonCyan.withOpacity(0.22)),
        ),
        child: _QuickAddContent(icon: icon, amount: amount, caption: caption),
      ),
    );
  }
}

class _QuickAddContent extends StatelessWidget {
  const _QuickAddContent({
    required this.icon,
    required this.amount,
    required this.caption,
  });

  final IconData icon;
  final String amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.neonCyan),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(amount, maxLines: 1, style: sora(13, 700)),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(caption, maxLines: 1, style: AppText.caption),
          ),
        ],
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.undo_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: sora(11, 600, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
