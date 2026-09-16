import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../domain/hydration.dart';

/// Asks for a drink size. Returns the amount in millilitres, or null if
/// dismissed.
///
/// Serves two jobs: logging a one-off custom drink (the defaults), and
/// re-pinning a quick-add preset, where the caller passes the preset's
/// current amount and a "SAVE" verb.
Future<int?> showCustomWaterSheet(
  BuildContext context, {
  String title = 'Log water',
  String subtitle = 'Pick a common size or enter your own.',
  String confirmVerb = 'ADD',
  int? initialMl,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC050A14),
    isScrollControlled: true,
    builder: (BuildContext context) => CustomWaterSheet(
      title: title,
      subtitle: subtitle,
      confirmVerb: confirmVerb,
      initialMl: initialMl,
    ),
  );
}

/// Common container sizes, offered as shortcuts above the field.
const List<int> _kSuggestedMl = <int>[150, 330, 750, 1000];

/// Owns its [TextEditingController], for the same reason the name and target
/// sheets do: a controller disposed by the caller dies while the sheet is
/// still animating out, and the still-mounted field rebuilds against it.
class CustomWaterSheet extends StatefulWidget {
  const CustomWaterSheet({
    super.key,
    this.title = 'Log water',
    this.subtitle = 'Pick a common size or enter your own.',
    this.confirmVerb = 'ADD',
    this.initialMl,
  });

  final String title;
  final String subtitle;
  final String confirmVerb;

  /// Pre-fills the field, for editing an existing preset.
  final int? initialMl;

  @override
  State<CustomWaterSheet> createState() => _CustomWaterSheetState();
}

class _CustomWaterSheetState extends State<CustomWaterSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialMl == null ? '' : '${widget.initialMl}',
  );

  @override
  void initState() {
    super.initState();
    // Cursor at the end, so a pre-filled amount can be corrected directly.
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    // Rebuild on typing so the Add button and the hint track the value.
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int? get _amount => int.tryParse(_controller.text.trim());

  bool get _valid {
    final int? ml = _amount;
    return ml != null && ml >= kMinDrinkMl && ml <= kMaxDrinkMl;
  }

  void _pick(int ml) {
    HapticFeedback.selectionClick();
    _controller.text = '$ml';
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(_amount);
  }

  @override
  Widget build(BuildContext context) {
    final int? ml = _amount;
    final bool showRangeHint = _controller.text.isNotEmpty && !_valid;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: GlassCard(
        radius: 28,
        opaque: true,
        highlighted: true,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.title, style: AppText.title),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: AppText.caption),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final int size in _kSuggestedMl)
                  GestureDetector(
                    onTap: () => _pick(size),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            ml == size ? AppColors.accentGradient : null,
                        color: ml == size
                            ? null
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ml == size
                              ? Colors.transparent
                              : AppColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        formatWaterMl(size),
                        style: sora(
                          12,
                          600,
                          color: ml == size
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: showRangeHint
                      ? AppColors.warning.withOpacity(0.6)
                      : AppColors.glassBorder,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textInputAction: TextInputAction.done,
                      style: sora(18, 700),
                      cursorColor: AppColors.neonCyan,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                        hintText: '0',
                        hintStyle: sora(18, 600, color: AppColors.textTertiary),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  Text('ml', style: sora(14, 600, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: showRangeHint ? 1 : 0,
              child: Text(
                'Enter between $kMinDrinkMl and $kMaxDrinkMl ml.',
                style: sora(11, 500, color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 12),
            NeonButton(
              label: _valid
                  ? '${widget.confirmVerb} ${formatWaterMl(ml!)}'
                  : widget.confirmVerb,
              height: 48,
              icon: Icons.water_drop_rounded,
              enabled: _valid,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
