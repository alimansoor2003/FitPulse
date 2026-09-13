import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/progress_layout.dart';
import 'settings_controller.dart';

/// The user's section order for the Progress screen, backed by
/// SharedPreferences.
///
/// Writes go to disk on every move rather than only when edit mode closes:
/// the list is five short strings, so the write is free, and it means a drag
/// survives the app being killed from the recents list mid-edit.
class ProgressLayoutNotifier extends Notifier<List<ProgressSection>> {
  static const String _prefsKey = 'progress_section_order';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<ProgressSection> build() {
    final List<String>? saved = _prefs.getStringList(_prefsKey);
    if (saved == null) return kDefaultProgressOrder;
    return progressOrderFrom(saved);
  }

  /// Applies a [ReorderableListView] drop.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final List<ProgressSection> next =
        reorderSections(state, oldIndex, newIndex);
    if (_sameOrder(next, state)) return;
    state = next;
    await _persist(next);
  }

  Future<void> resetToDefault() async {
    if (_sameOrder(kDefaultProgressOrder, state)) return;
    state = kDefaultProgressOrder;
    await _prefs.remove(_prefsKey);
  }

  bool get isCustomised => !_sameOrder(state, kDefaultProgressOrder);

  Future<void> _persist(List<ProgressSection> order) {
    return _prefs.setStringList(
      _prefsKey,
      <String>[
        for (final ProgressSection section in order) section.storageKey,
      ],
    );
  }

  static bool _sameOrder(List<ProgressSection> a, List<ProgressSection> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final NotifierProvider<ProgressLayoutNotifier, List<ProgressSection>>
    progressLayoutProvider =
    NotifierProvider<ProgressLayoutNotifier, List<ProgressSection>>(
  ProgressLayoutNotifier.new,
);
