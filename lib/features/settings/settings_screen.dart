import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/confirm_sheet.dart';
import '../../core/widgets/fade_in.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../core/widgets/section_header.dart';
import '../../data/services/gemini_food_service.dart' show kGeminiKeyUrl;
import '../../domain/nutrition.dart';
import '../../state/nutrition_providers.dart';
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

  Future<void> _editTargets(
    BuildContext context,
    WidgetRef ref,
    MacroTargets current,
  ) async {
    final MacroTargets? targets = await showModalBottomSheet<MacroTargets>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xCC050A14),
      isScrollControlled: true,
      builder: (BuildContext context) => _TargetsSheet(initial: current),
    );

    if (targets != null) {
      await ref.read(settingsProvider.notifier).setMacroTargets(targets);
    }
  }

  Future<void> _editApiKey(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final String? key = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xCC050A14),
      isScrollControlled: true,
      builder: (BuildContext context) => _ApiKeySheet(initialKey: current),
    );

    if (key != null) {
      await ref.read(settingsProvider.notifier).setGeminiApiKey(key);
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

        const SectionHeader(title: 'Nutrition'),
        FadeIn(
          delay: const Duration(milliseconds: 120),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: <Widget>[
                _ActionRow(
                  icon: Icons.local_fire_department_rounded,
                  accent: AppColors.neonCyan,
                  title: 'Daily targets',
                  subtitle: '${settings.macroTargets.calories} kcal - '
                      'P ${settings.macroTargets.proteinG.round()} / '
                      'C ${settings.macroTargets.carbsG.round()} / '
                      'F ${settings.macroTargets.fatG.round()} g',
                  onTap: () =>
                      _editTargets(context, ref, settings.macroTargets),
                ),
                const Divider(height: 18),
                _ActionRow(
                  icon: Icons.auto_awesome_rounded,
                  accent: settings.aiFoodEnabled
                      ? AppColors.neonGreen
                      : AppColors.textTertiary,
                  title: 'AI food parsing',
                  subtitle: settings.aiFoodEnabled
                      ? 'Connected - meal text is sent to Google Gemini'
                      : 'Off - add a Gemini API key to turn it on',
                  onTap: () =>
                      _editApiKey(context, ref, settings.geminiApiKey),
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
                  icon: Icons.no_food_rounded,
                  title: 'Clear food log',
                  subtitle: 'Removes every meal you have logged',
                  onTap: () async {
                    final bool ok = await showConfirmSheet(
                      context,
                      title: 'Clear the food log?',
                      message:
                          'Every food item you have logged will be deleted. '
                          'Your workouts and targets stay untouched.',
                      confirmLabel: 'Clear',
                      icon: Icons.no_food_rounded,
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref.read(nutritionRepositoryProvider).clearFoodLogs();
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
                    'FitPulse 1.0 - workout logs remain 100% local on your '
                    'phone. AI food parsing sends meal text directly to the '
                    'Google Gemini API using your personal key, and only '
                    'while a key is set.',
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
          // Wrap, not Row: three fixed-width chips in a Row overflow on a
          // narrow screen or at a large system text scale. Wrapping lets them
          // fall to a second line instead of being clipped.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((double option) {
              final bool isSelected = (option - selected).abs() < 0.01;
              return GestureDetector(
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
                    color: isSelected ? null : Colors.white.withOpacity(0.05),
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
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
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
    this.accent = AppColors.danger,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Red by default - these rows started out as the destructive data
  /// actions. The nutrition rows pass a neutral accent.
  final Color accent;

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
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: accent),
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

/// Daily calorie and macro goals.
///
/// Owns its controllers for the same reason [_NameSheet] does: they must not
/// be disposed while the sheet is still animating out.
class _TargetsSheet extends StatefulWidget {
  const _TargetsSheet({required this.initial});

  final MacroTargets initial;

  @override
  State<_TargetsSheet> createState() => _TargetsSheetState();
}

class _TargetsSheetState extends State<_TargetsSheet> {
  late final TextEditingController _calories =
      TextEditingController(text: '${widget.initial.calories}');
  late final TextEditingController _protein =
      TextEditingController(text: _grams(widget.initial.proteinG));
  late final TextEditingController _carbs =
      TextEditingController(text: _grams(widget.initial.carbsG));
  late final TextEditingController _fat =
      TextEditingController(text: _grams(widget.initial.fatG));

  static String _grams(double value) => value.round().toString();

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double _read(TextEditingController controller, double fallback) {
    final double? parsed =
        double.tryParse(controller.text.trim().replaceAll(',', '.'));
    return parsed == null || parsed.isNaN || parsed < 0 ? fallback : parsed;
  }

  void _submit() {
    Navigator.of(context).pop(
      MacroTargets(
        calories: _read(_calories, widget.initial.calories.toDouble()).round(),
        proteinG: _read(_protein, widget.initial.proteinG),
        carbsG: _read(_carbs, widget.initial.carbsG),
        fatG: _read(_fat, widget.initial.fatG),
      ),
    );
  }

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
        highlighted: true,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Daily targets', style: AppText.title),
            const SizedBox(height: 4),
            Text(
              'What the rings on the Today screen fill against.',
              style: AppText.caption,
            ),
            const SizedBox(height: 16),
            _TargetField(
              controller: _calories,
              label: 'Calories',
              suffix: 'kcal',
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TargetField(
                    controller: _protein,
                    label: 'Protein',
                    suffix: 'g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TargetField(
                    controller: _carbs,
                    label: 'Carbs',
                    suffix: 'g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TargetField(
                    controller: _fat,
                    label: 'Fat',
                    suffix: 'g',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            NeonButton(label: 'SAVE', height: 48, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _TargetField extends StatelessWidget {
  const _TargetField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppText.caption),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: sora(16, 700),
                  cursorColor: AppColors.neonCyan,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 2),
                  ),
                ),
              ),
              Text(suffix, style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gemini API key entry.
///
/// The key is stored in this device's SharedPreferences and sent only as a
/// request header to Google's endpoint. Popping an empty string clears it,
/// which turns AI parsing back off.
class _ApiKeySheet extends StatefulWidget {
  const _ApiKeySheet({required this.initialKey});

  final String initialKey;

  @override
  State<_ApiKeySheet> createState() => _ApiKeySheetState();
}

class _ApiKeySheetState extends State<_ApiKeySheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialKey);
  bool _obscured = true;
  bool _launchFailed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  void _clear() => Navigator.of(context).pop('');

  /// Opens Google AI Studio's key page. A failure is reported inside the
  /// sheet rather than thrown: a device with no app that can handle https
  /// should not take the settings screen down with it.
  Future<void> _openKeyPage() async {
    setState(() => _launchFailed = false);
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(kGeminiKeyUrl),
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      opened = false;
    }
    if (!opened && mounted) setState(() => _launchFailed = true);
  }

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
        highlighted: true,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('AI food parsing', style: AppText.title),
              const SizedBox(height: 6),
              Text(
                'The key is stored on this device only. With one set, the '
                'meal text you type in the food logger is sent to Google to '
                'be broken down into items and macros - nothing else is '
                'uploaded.',
                style: AppText.body,
              ),
              const SizedBox(height: 16),
              NeonButton(
                label: 'GET FREE GEMINI KEY',
                height: 48,
                icon: Icons.open_in_new_rounded,
                onPressed: _openKeyPage,
              ),
              const SizedBox(height: 14),
              const _KeyStep(
                number: 1,
                text: 'Tap "Get free Gemini key" and sign in with Google.',
              ),
              const _KeyStep(number: 2, text: 'Click "Create API key".'),
              const _KeyStep(
                number: 3,
                text: 'Copy the key and paste it in the box below.',
              ),
              if (_launchFailed) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Could not open a browser. Visit $kGeminiKeyUrl manually.',
                  style: sora(11, 500, color: AppColors.warning),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(left: 14, right: 4),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: widget.initialKey.isEmpty,
                        obscureText: _obscured,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        style: sora(14, 600),
                        cursorColor: AppColors.neonCyan,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          hintText: 'AIza...',
                          hintStyle: sora(
                            14,
                            500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _obscured = !_obscured),
                      iconSize: 18,
                      color: AppColors.textTertiary,
                      tooltip: _obscured ? 'Show key' : 'Hide key',
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              NeonButton(label: 'SAVE KEY', height: 48, onPressed: _submit),
              if (widget.initialKey.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Center(
                  child: GhostButton(
                    label: 'Remove key',
                    icon: Icons.link_off_rounded,
                    color: AppColors.danger,
                    onPressed: _clear,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One numbered line of the key micro-guide.
class _KeyStep extends StatelessWidget {
  const _KeyStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 19,
            height: 19,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.28)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: sora(10, 700, color: AppColors.neonCyan),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: sora(
                12,
                500,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
