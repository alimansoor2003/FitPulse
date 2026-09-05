import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/root_shell.dart';
import 'state/settings_controller.dart';

class FitPulseApp extends ConsumerWidget {
  const FitPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool onboarded = ref.watch(
      settingsProvider.select((AppSettings s) => s.onboarded),
    );

    return MaterialApp(
      title: 'FitPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      builder: (BuildContext context, Widget? child) {
        // Keep the layout stable regardless of the device font scale.
        //
        // This must depend on the text scale *only*. Reading the whole
        // MediaQueryData here (MediaQuery.of) subscribed the entire app to
        // every MediaQuery change - including viewInsets, which ticks on
        // every frame the soft keyboard animates. That rebuilt the whole
        // tree from the root each frame and made tapping into a field feel
        // slow. withClampedTextScaling depends on the textScaler aspect
        // alone, so the keyboard no longer rebuilds anything up here.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.15,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        child: onboarded
            ? const RootShell(key: ValueKey<String>('shell'))
            : const OnboardingScreen(key: ValueKey<String>('onboarding')),
      ),
    );
  }
}
