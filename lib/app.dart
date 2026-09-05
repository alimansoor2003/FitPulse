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
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1).clamp(0.9, 1.15),
            ),
          ),
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
