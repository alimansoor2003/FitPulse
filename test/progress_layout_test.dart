import 'package:fitpulse/domain/progress_layout.dart';
import 'package:fitpulse/state/progress_layout.dart';
import 'package:fitpulse/state/settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('progressOrderFrom', () {
    test('restores a saved order exactly', () {
      final List<ProgressSection> order = progressOrderFrom(<String>[
        'exercise_history',
        'macro_overview',
        'weekly_consistency',
        'one_rm_chart',
        'volume_trend',
      ]);

      expect(order, <ProgressSection>[
        ProgressSection.exerciseHistory,
        ProgressSection.macroOverview,
        ProgressSection.weeklyConsistency,
        ProgressSection.oneRmChart,
        ProgressSection.volumeTrend,
      ]);
    });

    test('appends a section the saved order has never heard of', () {
      // What an older install's saved list looks like after an update adds a
      // section: it must appear rather than vanish.
      final List<ProgressSection> order = progressOrderFrom(<String>[
        'volume_trend',
        'weekly_consistency',
      ]);

      expect(order.take(2), <ProgressSection>[
        ProgressSection.volumeTrend,
        ProgressSection.weeklyConsistency,
      ]);
      expect(order.toSet(), ProgressSection.values.toSet(),
          reason: 'every section has to be reachable');
      expect(order, hasLength(ProgressSection.values.length));
    });

    test('drops a key that no longer maps to a section', () {
      final List<ProgressSection> order = progressOrderFrom(<String>[
        'volume_trend',
        'a_section_we_deleted',
        'weekly_consistency',
      ]);

      expect(order, hasLength(ProgressSection.values.length));
      expect(order.first, ProgressSection.volumeTrend);
      expect(order[1], ProgressSection.weeklyConsistency);
    });

    test('collapses duplicates to the first appearance', () {
      final List<ProgressSection> order = progressOrderFrom(<String>[
        'macro_overview',
        'macro_overview',
        'volume_trend',
      ]);

      expect(order.where((ProgressSection s) => s == ProgressSection.macroOverview),
          hasLength(1));
      expect(order.first, ProgressSection.macroOverview);
      expect(order, hasLength(ProgressSection.values.length));
    });

    test('an empty or junk list falls back to the default order', () {
      expect(progressOrderFrom(const <String>[]), kDefaultProgressOrder);
      expect(progressOrderFrom(const <String>['nope']), kDefaultProgressOrder);
    });
  });

  group('reorderSections', () {
    test('moving down applies the framework off-by-one', () {
      // ReorderableListView reports the destination before the dragged item
      // was lifted out, so "0 -> 3" means "end up at index 2".
      final List<ProgressSection> next =
          reorderSections(kDefaultProgressOrder, 0, 3);

      expect(next[2], kDefaultProgressOrder.first);
      expect(next.first, kDefaultProgressOrder[1]);
      expect(next.toSet(), kDefaultProgressOrder.toSet());
    });

    test('moving up lands on the reported index', () {
      final List<ProgressSection> next =
          reorderSections(kDefaultProgressOrder, 4, 0);

      expect(next.first, kDefaultProgressOrder[4]);
      expect(next, hasLength(kDefaultProgressOrder.length));
    });

    test('a no-op drop leaves the order alone', () {
      final List<ProgressSection> next =
          reorderSections(kDefaultProgressOrder, 2, 2);
      expect(next, kDefaultProgressOrder);
    });

    test('an out-of-range index is ignored rather than throwing', () {
      expect(reorderSections(kDefaultProgressOrder, 99, 0),
          kDefaultProgressOrder);
    });
  });

  group('ProgressLayoutNotifier', () {
    Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final SharedPreferences instance =
          await SharedPreferences.getInstance();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(instance),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts on the default order with nothing saved', () async {
      final ProviderContainer container = await containerWith(<String, Object>{});
      expect(container.read(progressLayoutProvider), kDefaultProgressOrder);
      expect(
        container.read(progressLayoutProvider.notifier).isCustomised,
        isFalse,
      );
    });

    test('a reorder is written to disk immediately', () async {
      final ProviderContainer container =
          await containerWith(<String, Object>{});

      await container.read(progressLayoutProvider.notifier).reorder(4, 0);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('progress_section_order'),
        <String>[
          for (final ProgressSection s
              in container.read(progressLayoutProvider))
            s.storageKey,
        ],
        reason: 'the drop must survive the app being killed mid-edit',
      );
      expect(
        container.read(progressLayoutProvider.notifier).isCustomised,
        isTrue,
      );
    });

    test('a saved order is picked up on the next launch', () async {
      final ProviderContainer container = await containerWith(<String, Object>{
        'progress_section_order': <String>[
          'macro_overview',
          'one_rm_chart',
          'weekly_consistency',
          'volume_trend',
          'exercise_history',
        ],
      });

      expect(
        container.read(progressLayoutProvider).first,
        ProgressSection.macroOverview,
      );
    });

    test('reset clears the stored order', () async {
      final ProviderContainer container = await containerWith(<String, Object>{
        'progress_section_order': <String>['exercise_history'],
      });

      await container.read(progressLayoutProvider.notifier).resetToDefault();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('progress_section_order'), isNull);
      expect(container.read(progressLayoutProvider), kDefaultProgressOrder);
    });
  });
}
