import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../core/widgets/section_header.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final String? name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xCC050A14),
      isScrollControlled: true,
      builder: (BuildContext context) => _NameSheet(initialName: current),
    );

    if (name != null) {
      await ref.read(settingsProvider.notifier).setName(name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final SettingsController controller =
        ref.read(settingsProvider.notifier);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 18,
        20,
        120,
      ),
      children: <Widget>[
        FadeIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Settings', style: AppText.display),
              const SizedBox(height: 4),
              Text(
                'Tune the app around how you train.',
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        FadeIn(
          delay: const Duration(milliseconds: 60),
          child: GlassCard(
            onTap: () => _editName(context, ref, settings.userName),
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    settings.userName.isEmpty
                        ? '?'
                        : settings.userName.substring(0, 1).toUpperCase(),
                    style: sora(18, 700, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(settings.userName, style: sora(15, 600)),
                      const SizedBox(height: 2),
                      Text('Tap to change your name', style: AppText.caption),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_rounded,
                  size: 17,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Training'),
        FadeIn(
          delay: const Duration(milliseconds: 100),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
            child: Column(
              children: <Widget>[
                _StepperRow(
                  title: 'Weekly goal',
                  subtitle: 'Sessions per week used by the progress ring',
                  value: '${settings.weeklyGoal}',
                  onMinus: () =>
                      controller.setWeeklyGoal(settings.weeklyGoal - 1),
                  onPlus: () =>
                      controller.setWeeklyGoal(settings.weeklyGoal + 1),
                ),
                const Divider(height: 22),
                _SliderRow(
                  title: 'Default rest',
                  value: settings.defaultRestSeconds.toDouble(),
                  min: 30,
                  max: 240,
                  divisions: 14,
                  label: formatClock(settings.defaultRestSeconds),
                  onChanged: (double v) =>
                      controller.setDefaultRest(v.round()),
                ),
                const Divider(height: 22),
                _SwitchRow(
                  title: 'Auto-start rest timer',
                  subtitle: 'Starts counting the moment a set is ticked off',
                  value: settings.autoStartRest,
                  onChanged: controller.setAutoStartRest,
                ),
                const Divider(height: 22),
                _ChoiceRow(
                  title: 'Overload step',
                  subtitle: 'Added to the suggested target weight',
                  options: const <double>[1.25, 2.5, 5.0],
                  selected: settings.weightStep,
                  onSelect: controller.setWeightStep,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Display'),
        FadeIn(
          delay: const Duration(milliseconds: 140),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            child: _SwitchRow(
              title: 'Arabic exercise names',
              subtitle: 'Show the Arabic name under every exercise',
              value: settings.showArabicNames,
              onChanged: controller.setShowArabicNames,
            ),
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader(title: 'Data'),
        FadeIn(
          delay: const Duration(milliseconds: 180),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: <Widget>[
                _ActionRow(
                  icon: Icons.delete_sweep_rounded,
                  title: 'Clear workout history',
                  subtitle: 'Removes every session and logged set',
                  onTap: () async {
                    final bool ok = await showConfirmSheet(
                      context,
                      title: 'Clear all history?',
                      message:
                          'Every session and set you have logged will be '
                          'deleted. Your routine stays untouched.',
                      confirmLabel: 'Clear',
                      icon: Icons.delete_sweep_rounded,
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref.read(repositoryProvider).clearHistory();
                    HapticFeedback.mediumImpact();
                  },
                ),
                const Divider(height: 18),
                _ActionRow(
                  icon: Icons.restart_alt_rounded,
                  title: 'Reset routine to default',
                  subtitle: 'Restores the original 3-day split and clears logs',
                  onTap: () async {
                    final bool ok = await showConfirmSheet(
                      context,
                      title: 'Reset everything?',
                      message:
                          'The seeded 3-day split will be restored and all '
                          'logged sessions removed.',
                      confirmLabel: 'Reset',
                      icon: Icons.restart_alt_rounded,
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref.read(repositoryProvider).resetEverything();
                    ref.invalidate(allExercisesProvider);
                    HapticFeedback.mediumImpact();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        FadeIn(
          delay: const Duration(milliseconds: 220),
          child: GlassCard(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FitPulse 1.0 - everything is stored locally in an SQLite '
                    'database on this device. No account, no network.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: sora(14, 600)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          _RoundButton(icon: Icons.remove_rounded, onTap: onMinus),
          SizedBox(
            width: 38,
            child: Center(child: Text(value, style: sora(16, 700))),
          ),
          _RoundButton(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title, style: sora(14, 600))),
              Text(label, style: sora(14, 700, color: AppColors.neonCyan)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: sora(14, 600)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (bool v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final List<double> options;
  final double selected;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: sora(14, 600)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.caption),
          const SizedBox(height: 12),
          Row(
            children: options.map((double option) {
              final bool isSelected = (option - selected).abs() < 0.01;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(option);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.accentGradient : null,
                      color:
                          isSelected ? null : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      '+${formatWeight(option)} kg',
                      style: sora(
                        12,
                        600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: AppColors.danger),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: sora(14, 600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// The name editor shown as a modal sheet.
///
/// This owns its [TextEditingController] so the controller lives exactly as
/// long as the field that uses it. Creating it in the caller and disposing it
/// as soon as `showModalBottomSheet` returned meant it died while the sheet
/// was still animating out - the still-mounted TextField then rebuilt against
/// a disposed controller, which surfaced as a full red error screen.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initialName});

  final String initialName;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: GlassCard(
        radius: 28,
        opaque: true,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        highlighted: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Your name', style: AppText.title),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: sora(15, 600),
                cursorColor: AppColors.neonCyan,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 18),
            NeonButton(label: 'SAVE', height: 48, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
