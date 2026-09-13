import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../data/services/gemini_food_service.dart';
import '../../domain/nutrition.dart';
import '../../state/nutrition_providers.dart';
import '../../state/settings_controller.dart';

/// Opens the food logger. Returns the number of items written, or null if the
/// sheet was dismissed without logging anything.
Future<int?> showFoodLoggerSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC050A14),
    isScrollControlled: true,
    builder: (BuildContext context) => const FoodLoggerSheet(),
  );
}

/// Natural-language food logger.
///
/// The sheet owns every [TextEditingController] it shows - the input field
/// here, the per-item fields in [_ReviewList] - so no controller can outlive
/// the field using it while the sheet animates out.
class FoodLoggerSheet extends ConsumerStatefulWidget {
  const FoodLoggerSheet({super.key});

  @override
  ConsumerState<FoodLoggerSheet> createState() => _FoodLoggerSheetState();
}

class _FoodLoggerSheetState extends ConsumerState<FoodLoggerSheet> {
  final TextEditingController _input = TextEditingController();
  late MealType _meal = MealType.forTime(DateTime.now());

  /// Hands out ids for manually added rows. The parser numbers its own items
  /// from 0, so manual rows start well past them to stay unique within a
  /// review list that mixes both.
  int _nextManualId = 1000;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _parse() {
    FocusScope.of(context).unfocus();
    ref
        .read(foodLogControllerProvider.notifier)
        .parse(_input.text, defaultMeal: _meal);
  }

  /// Drops straight into the review list with one blank row - the offline and
  /// no-API-key path, and the "the AI got it wrong, I'll type it" path.
  void _logManually() {
    FocusScope.of(context).unfocus();
    ref.read(foodLogControllerProvider.notifier).review(<ParsedFood>[
      ParsedFood(
        localId: _nextManualId++,
        name: '',
        mealType: _meal,
        calories: 0,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
      ),
    ]);
  }

  ParsedFood _blankItem() => ParsedFood(
        localId: _nextManualId++,
        name: '',
        mealType: _meal,
        calories: 0,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
      );

  Future<void> _confirm(List<ParsedFood> items) async {
    await ref.read(foodLogControllerProvider.notifier).submit(items);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(items.length);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FoodLogState> state = ref.watch(foodLogControllerProvider);
    final bool aiEnabled =
        ref.watch(settingsProvider.select((AppSettings s) => s.aiFoodEnabled));

    final Widget body = switch (state) {
      AsyncError(:final Object error) => _ErrorView(
          failure: error is FoodParseException
              ? error
              : FoodParseException('$error'),
          onRetry: _parse,
          onManual: _logManually,
          onBack: ref.read(foodLogControllerProvider.notifier).reset,
        ),
      AsyncLoading<FoodLogState>() => const _ParsingView(),
      AsyncData<FoodLogState>(value: final FoodLogReview review) => _ReviewList(
          key: ValueKey<int>(review.items.hashCode),
          initial: review.items,
          onAdd: _blankItem,
          onConfirm: _confirm,
          onBack: ref.read(foodLogControllerProvider.notifier).reset,
        ),
      AsyncData<FoodLogState>(value: FoodLogSubmitted(:final int count)) =>
        _SubmittedView(count: count),
      _ => _InputView(
          controller: _input,
          meal: _meal,
          aiEnabled: aiEnabled,
          onMealChanged: (MealType meal) => setState(() => _meal = meal),
          onParse: _parse,
          onManual: _logManually,
        ),
    };

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: GlassCard(
            radius: 28,
            opaque: true,
            highlighted: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- header

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle, this.icon});

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.25)),
            ),
            child: Icon(icon, size: 20, color: AppColors.neonCyan),
          ),
          const SizedBox(width: 13),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AppText.title),
              const SizedBox(height: 3),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- input

class _InputView extends StatelessWidget {
  const _InputView({
    required this.controller,
    required this.meal,
    required this.aiEnabled,
    required this.onMealChanged,
    required this.onParse,
    required this.onManual,
  });

  final TextEditingController controller;
  final MealType meal;
  final bool aiEnabled;
  final ValueChanged<MealType> onMealChanged;
  final VoidCallback onParse;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SheetHeader(
          title: 'Log Food',
          subtitle: aiEnabled
              ? 'Describe the meal and Gemini will break it down.'
              : 'Add a Gemini API key in Settings to parse meals with AI.',
          icon: Icons.restaurant_rounded,
        ),
        const SizedBox(height: 18),
        _MealChips(selected: meal, onSelect: onMealChanged),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: controller,
            autofocus: aiEnabled,
            enabled: aiEnabled,
            minLines: 2,
            maxLines: 4,
            maxLength: 400,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            style: sora(14, 500, height: 1.4),
            cursorColor: AppColors.neonCyan,
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: '3 eggs, 2 slices of sourdough toast, black coffee',
              hintStyle: sora(14, 400, color: AppColors.textTertiary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (aiEnabled)
          NeonButton(
            label: 'PARSE WITH AI',
            height: 52,
            icon: Icons.auto_awesome_rounded,
            onPressed: onParse,
          )
        else
          NeonButton(
            label: 'LOG MANUALLY',
            height: 52,
            icon: Icons.edit_rounded,
            onPressed: onManual,
          ),
        const SizedBox(height: 10),
        if (aiEnabled)
          Center(
            child: GhostButton(
              label: 'Log manually instead',
              icon: Icons.edit_rounded,
              onPressed: onManual,
            ),
          )
        else
          Row(
            children: <Widget>[
              const Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Without a key nothing leaves this device.',
                  style: AppText.caption,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MealChips extends StatelessWidget {
  const _MealChips({required this.selected, required this.onSelect});

  final MealType selected;
  final ValueChanged<MealType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final MealType type in MealType.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: type == MealType.values.last ? 0 : 6,
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(type);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient:
                        type == selected ? AppColors.accentGradient : null,
                    color: type == selected
                        ? null
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: type == selected
                          ? Colors.transparent
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Text(
                    type.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sora(
                      11,
                      600,
                      color: type == selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ parsing

class _ParsingView extends StatelessWidget {
  const _ParsingView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.neonCyan),
            ),
          ),
          const SizedBox(height: 18),
          Text('Reading your meal', style: sora(15, 600)),
          const SizedBox(height: 5),
          Text(
            'Estimating calories and macros...',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- error

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.failure,
    required this.onRetry,
    required this.onManual,
    required this.onBack,
  });

  final FoodParseException failure;
  final VoidCallback onRetry;
  final VoidCallback onManual;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.danger.withOpacity(0.25)),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text("That didn't work", style: AppText.title),
                  const SizedBox(height: 6),
                  Text(failure.message, style: AppText.body),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (failure.canRetry)
          NeonButton(
            label: 'TRY AGAIN',
            height: 50,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        if (failure.canRetry) const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Center(
                child: GhostButton(
                  label: 'Back',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: GhostButton(
                  label: 'Log manually',
                  icon: Icons.edit_rounded,
                  color: AppColors.neonCyan,
                  onPressed: onManual,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- submitted

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            size: 40,
            color: AppColors.neonGreen,
          ),
          const SizedBox(height: 14),
          Text(
            count == 0
                ? 'Nothing to log'
                : 'Logged $count item${count == 1 ? '' : 's'}',
            style: sora(15, 600),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- review

/// The editable list of parsed items.
///
/// It takes [initial] once and then owns the values outright, in its own
/// controllers. Nothing flows back into Riverpod until "Confirm & Log", which
/// is what keeps typing here off the rebuild path entirely - the same lesson
/// the workout set rows taught us.
class _ReviewList extends StatefulWidget {
  const _ReviewList({
    super.key,
    required this.initial,
    required this.onAdd,
    required this.onConfirm,
    required this.onBack,
  });

  final List<ParsedFood> initial;
  final ParsedFood Function() onAdd;
  final Future<void> Function(List<ParsedFood>) onConfirm;
  final VoidCallback onBack;

  @override
  State<_ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<_ReviewList> {
  late final List<_EditableItem> _items = <_EditableItem>[
    for (final ParsedFood food in widget.initial) _EditableItem(food),
  ];

  /// Rows the user swiped away. Their controllers stay alive until the whole
  /// sheet is disposed: the totals line listens to every controller, and
  /// disposing one while that merged listener is still attached would throw
  /// on the next rebuild.
  final List<_EditableItem> _removed = <_EditableItem>[];

  late Listenable _totalsListenable = _mergeTotals();
  bool _submitting = false;

  Listenable _mergeTotals() => Listenable.merge(<Listenable>[
        for (final _EditableItem item in _items) ...item.numberFields,
      ]);

  @override
  void dispose() {
    for (final _EditableItem item in <_EditableItem>[..._items, ..._removed]) {
      item.dispose();
    }
    super.dispose();
  }

  void _remove(_EditableItem item) {
    setState(() {
      _items.remove(item);
      _removed.add(item);
      _totalsListenable = _mergeTotals();
    });
    HapticFeedback.selectionClick();
  }

  void _add() {
    setState(() {
      _items.add(_EditableItem(widget.onAdd()));
      _totalsListenable = _mergeTotals();
    });
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    await widget.onConfirm(
      <ParsedFood>[for (final _EditableItem item in _items) item.toFood()],
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SheetHeader(
          title: 'Review',
          subtitle: _items.isEmpty
              ? 'Nothing left - add an item or go back.'
              : 'Fix anything that looks off, then log it.',
          icon: Icons.fact_check_rounded,
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: _items.length,
            itemBuilder: (BuildContext context, int index) {
              final _EditableItem item = _items[index];
              return Dismissible(
                key: ValueKey<int>(item.localId),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _remove(item),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                ),
                child: _ReviewItemCard(item: item, onRemove: () => _remove(item)),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: GhostButton(
            label: 'Add item',
            icon: Icons.add_rounded,
            color: AppColors.neonCyan,
            onPressed: _add,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _totalsListenable,
          builder: (BuildContext context, Widget? _) => _TotalsRow(
            items: <ParsedFood>[
              for (final _EditableItem item in _items) item.toFood(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        NeonButton(
          label: _submitting ? 'LOGGING...' : 'CONFIRM & LOG TO FITPULSE',
          height: 52,
          icon: Icons.check_rounded,
          enabled: _items.isNotEmpty && !_submitting,
          onPressed: _confirm,
        ),
        const SizedBox(height: 8),
        Center(
          child: GhostButton(
            label: 'Start over',
            icon: Icons.arrow_back_rounded,
            onPressed: _submitting ? null : widget.onBack,
          ),
        ),
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.items});

  final List<ParsedFood> items;

  @override
  Widget build(BuildContext context) {
    final DailyMacros totals = DailyMacros(
      calories:
          items.fold<int>(0, (int sum, ParsedFood f) => sum + f.calories),
      proteinG: items.fold<double>(
        0,
        (double sum, ParsedFood f) => sum + f.proteinG,
      ),
      carbsG:
          items.fold<double>(0, (double sum, ParsedFood f) => sum + f.carbsG),
      fatG: items.fold<double>(0, (double sum, ParsedFood f) => sum + f.fatG),
      itemCount: items.length,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Total',
              style: sora(12, 600, color: AppColors.textSecondary),
            ),
          ),
          Text('${totals.calories}', style: sora(15, 700)),
          const SizedBox(width: 3),
          Text('kcal', style: AppText.caption),
          const SizedBox(width: 12),
          Text(
            'P ${totals.proteinG.round()} / C ${totals.carbsG.round()} / '
            'F ${totals.fatG.round()}',
            style: sora(11, 600, color: AppColors.neonCyan),
          ),
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({required this.item, required this.onRemove});

  final _EditableItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: item.name,
                  textCapitalization: TextCapitalization.sentences,
                  style: sora(14, 600),
                  cursorColor: AppColors.neonCyan,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Food name',
                    hintStyle: sora(14, 500, color: AppColors.textTertiary),
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                color: AppColors.textTertiary,
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ItemMealSelector(item: item),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _NumberField(controller: item.calories, label: 'kcal'),
              const SizedBox(width: 8),
              _NumberField(controller: item.protein, label: 'P g'),
              const SizedBox(width: 8),
              _NumberField(controller: item.carbs, label: 'C g'),
              const SizedBox(width: 8),
              _NumberField(controller: item.fat, label: 'F g'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Meal picker for a single row. Stateful because the selection lives on the
/// [_EditableItem], not in the parent's state - repainting just this strip
/// keeps the other rows (and their text fields) out of the rebuild.
class _ItemMealSelector extends StatefulWidget {
  const _ItemMealSelector({required this.item});

  final _EditableItem item;

  @override
  State<_ItemMealSelector> createState() => _ItemMealSelectorState();
}

class _ItemMealSelectorState extends State<_ItemMealSelector> {
  @override
  Widget build(BuildContext context) {
    return _MealChips(
      selected: widget.item.mealType,
      onSelect: (MealType meal) =>
          setState(() => widget.item.mealType = meal),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: AppText.caption),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textAlign: TextAlign.start,
              style: sora(14, 700),
              cursorColor: AppColors.neonCyan,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(top: 2),
                hintText: '0',
                hintStyle: sora(14, 600, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One editable row: the controllers plus the meal choice, owned by
/// [_ReviewListState] and disposed with it.
class _EditableItem {
  _EditableItem(ParsedFood food)
      : localId = food.localId,
        mealType = food.mealType,
        name = TextEditingController(text: food.name),
        calories = TextEditingController(text: _text(food.calories)),
        protein = TextEditingController(text: _text(food.proteinG)),
        carbs = TextEditingController(text: _text(food.carbsG)),
        fat = TextEditingController(text: _text(food.fatG));

  final int localId;
  MealType mealType;
  final TextEditingController name;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;

  /// The fields the running total is derived from.
  List<Listenable> get numberFields =>
      <Listenable>[calories, protein, carbs, fat];

  ParsedFood toFood() => ParsedFood(
        localId: localId,
        name: name.text.trim(),
        mealType: mealType,
        calories: _number(calories).round(),
        proteinG: _number(protein),
        carbsG: _number(carbs),
        fatG: _number(fat),
      );

  void dispose() {
    name.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
  }

  /// Zero reads as an empty field, so a row the model left blank invites a
  /// number instead of showing a "0" the user has to select and delete.
  static String _text(num value) {
    if (value <= 0) return '';
    if (value is int || value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  /// Accepts a comma decimal separator, which is what an Arabic or European
  /// keyboard offers first.
  static double _number(TextEditingController controller) {
    final double parsed =
        double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    return parsed.isFinite && parsed > 0 ? parsed : 0;
  }
}
