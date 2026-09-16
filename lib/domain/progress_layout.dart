/// The reorderable sections of the Progress screen.
///
/// [storageKey] is what lands in SharedPreferences, so it is deliberately
/// independent of the enum name and of the display [title] - renaming either
/// of those must not silently reset everyone's saved layout.
enum ProgressSection {
  weeklyConsistency('weekly_consistency', 'Weekly Consistency'),
  volumeTrend('volume_trend', 'Session Volume'),
  macroOverview('macro_overview', 'Nutrition Trends'),
  hydrationTrend('hydration_trend', 'Hydration Trends'),
  oneRmChart('one_rm_chart', 'Strength Progression'),
  exerciseHistory('exercise_history', 'All Sessions');

  const ProgressSection(this.storageKey, this.title);

  final String storageKey;
  final String title;

  static ProgressSection? fromKey(String key) {
    for (final ProgressSection section in ProgressSection.values) {
      if (section.storageKey == key) return section;
    }
    return null;
  }
}

/// The order a fresh install starts with.
const List<ProgressSection> kDefaultProgressOrder = ProgressSection.values;

/// Rebuilds a section order from the keys stored on disk.
///
/// Saved orders are not trusted to still describe the app that reads them, so
/// this is a merge rather than a parse:
///
///   - keys that no longer map to a section are dropped (a section removed in
///     a later version);
///   - a section missing from the saved list is appended in its default
///     position relative to the other newcomers (a section *added* in a later
///     version, which is the case that would otherwise make it invisible);
///   - duplicates collapse to their first appearance.
///
/// The result therefore always contains every section exactly once, whatever
/// was on disk.
List<ProgressSection> progressOrderFrom(List<String> savedKeys) {
  final Set<ProgressSection> seen = <ProgressSection>{};
  final List<ProgressSection> order = <ProgressSection>[];

  for (final String key in savedKeys) {
    final ProgressSection? section = ProgressSection.fromKey(key);
    if (section != null && seen.add(section)) order.add(section);
  }
  for (final ProgressSection section in kDefaultProgressOrder) {
    if (seen.add(section)) order.add(section);
  }
  return order;
}

/// Moves the item at [oldIndex] to [newIndex], applying the off-by-one that
/// [ReorderableListView] expects when an item travels downwards.
///
/// Pure, because that adjustment is the single easiest thing to get wrong
/// here and it is worth testing on its own.
List<ProgressSection> reorderSections(
  List<ProgressSection> order,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex < 0 || oldIndex >= order.length) return order;

  final List<ProgressSection> next = List<ProgressSection>.of(order);
  // The framework reports the target slot as it was *before* the item was
  // lifted out, so dragging downwards overshoots by one.
  final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
  final ProgressSection moved = next.removeAt(oldIndex);
  next.insert(target.clamp(0, next.length), moved);
  return next;
}
