import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/db/app_database.dart';
import '../../../domain/models.dart';

/// One editable set: weight x reps plus the completion toggle.
///
/// The previous session's numbers are shown as hint (ghost) text inside the
/// fields, so the target is visible without pre-filling anything.
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.log,
    required this.ghost,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggle,
  });

  final SetLog log;
  final GhostSet? ghost;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onToggle;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  /// How long to wait after the last keystroke before writing to the database.
  ///
  /// Writing on *every* keystroke made typing stutter badly: each write made
  /// the Drift stream re-emit, which rebuilt every exercise card and set row
  /// in the session. Worse, a write that landed after the next character was
  /// typed came back stale and overwrote the field mid-edit, so characters
  /// visibly reverted. Batching to one write per pause fixes both.
  static const Duration _writeDelay = Duration(milliseconds: 400);

  late final TextEditingController _weight =
      TextEditingController(text: _weightText(widget.log.weightKg));
  late final TextEditingController _reps =
      TextEditingController(text: _repsText(widget.log.reps));

  final FocusNode _weightFocus = FocusNode();
  final FocusNode _repsFocus = FocusNode();

  Timer? _weightTimer;
  Timer? _repsTimer;

  static String _weightText(double value) =>
      value <= 0 ? '' : formatWeight(value);

  static String _repsText(int value) => value <= 0 ? '' : '$value';

  double get _parsedWeight => double.tryParse(_weight.text.trim()) ?? 0;

  int get _parsedReps => int.tryParse(_reps.text.trim()) ?? 0;

  bool get _busyEditing =>
      _weightTimer?.isActive == true ||
      _repsTimer?.isActive == true ||
      _weightFocus.hasFocus ||
      _repsFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    // Commit as soon as a field loses focus so nothing waits on the timer.
    _weightFocus.addListener(() {
      if (!_weightFocus.hasFocus) _flushWeight();
    });
    _repsFocus.addListener(() {
      if (!_repsFocus.hasFocus) _flushReps();
    });
  }

  void _onWeightTyped() {
    _weightTimer?.cancel();
    _weightTimer = Timer(_writeDelay, _flushWeight);
  }

  void _onRepsTyped() {
    _repsTimer?.cancel();
    _repsTimer = Timer(_writeDelay, _flushReps);
  }

  void _flushWeight() {
    _weightTimer?.cancel();
    widget.onWeightChanged(_parsedWeight);
  }

  void _flushReps() {
    _repsTimer?.cancel();
    widget.onRepsChanged(_parsedReps);
  }

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While the user is typing (or a write is still queued) the field is the
    // source of truth - never let an in-flight database value clobber it.
    if (_busyEditing) return;

    if (_parsedWeight != widget.log.weightKg) {
      _weight.text = _weightText(widget.log.weightKg);
    }
    if (_parsedReps != widget.log.reps) {
      _reps.text = _repsText(widget.log.reps);
    }
  }

  @override
  void dispose() {
    // Leaving the screen mid-edit must still save what was typed.
    if (_weightTimer?.isActive == true) _flushWeight();
    if (_repsTimer?.isActive == true) _flushReps();
    _weightTimer?.cancel();
    _repsTimer?.cancel();
    _weightFocus.dispose();
    _repsFocus.dispose();
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool done = widget.log.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done
            ? AppColors.neonGreen.withOpacity(0.08)
            : AppColors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? AppColors.neonGreen.withOpacity(0.32)
              : AppColors.glassBorder,
        ),
      ),
      child: Row(
        children: <Widget>[
          _IndexBadge(index: widget.log.setIndex, done: done),
          const SizedBox(width: 10),
          Expanded(
            child: _NumberField(
              controller: _weight,
              focusNode: _weightFocus,
              hint: widget.ghost == null
                  ? '-'
                  : formatWeight(widget.ghost!.weightKg),
              suffix: 'kg',
              decimal: true,
              onChanged: (String _) => _onWeightTyped(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NumberField(
              controller: _reps,
              focusNode: _repsFocus,
              hint: widget.ghost == null ? '-' : '${widget.ghost!.reps}',
              suffix: 'reps',
              decimal: false,
              onChanged: (String _) => _onRepsTyped(),
            ),
          ),
          const SizedBox(width: 8),
          _CheckButton(
            done: done,
            onTap: () {
              // Commit anything still queued before the toggle reads the row.
              if (_weightTimer?.isActive == true) _flushWeight();
              if (_repsTimer?.isActive == true) _flushReps();
              widget.onToggle();
            },
          ),
        ],
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index, required this.done});

  final int index;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? AppColors.neonGreen.withOpacity(0.16)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$index',
        style: sora(
          11,
          700,
          color: done ? AppColors.neonGreen : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.suffix,
    required this.decimal,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String suffix;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(
                  decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                ),
                LengthLimitingTextInputFormatter(decimal ? 6 : 3),
              ],
              style: sora(15, 700),
              cursorColor: AppColors.neonCyan,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: sora(15, 600, color: AppColors.textTertiary),
              ),
            ),
          ),
          Text(suffix, style: AppText.caption),
        ],
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: done
              ? const LinearGradient(
                  colors: <Color>[AppColors.neonGreen, Color(0xFF12C46F)],
                )
              : null,
          color: done ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: done
                ? Colors.transparent
                : AppColors.glassBorder,
          ),
          // Both states carry a shadow of identical geometry and differ only
          // in colour, so the transition interpolates colour alone.
          //
          // Animating a shadow to/from null instead makes BoxShadow.lerp
          // scale it by (1 - t), and Curves.easeOutBack overshoots past 1.0 -
          // driving that factor negative. BoxShadow extends ui.Shadow, whose
          // constructor asserts blurRadius >= 0, so un-completing a set threw
          // inside dart:ui/painting.dart and Flutter replaced the row with a
          // red error box.
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: done
                  ? AppColors.neonGreen.withOpacity(0.35)
                  : Colors.transparent,
              blurRadius: 16,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Icon(
          Icons.check_rounded,
          size: 20,
          color: done ? Colors.white : AppColors.textTertiary,
        ),
      ),
    );
  }
}
