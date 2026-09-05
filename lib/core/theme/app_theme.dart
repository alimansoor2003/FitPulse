import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bgDeep,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark {
    final ColorScheme scheme = const ColorScheme.dark().copyWith(
      primary: AppColors.neonBlue,
      secondary: AppColors.neonCyan,
      surface: AppColors.bgElevated,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgDeep,
      fontFamily: 'Sora',
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displaySmall: AppText.display,
        titleLarge: AppText.title,
        titleMedium: AppText.section,
        bodyMedium: AppText.body,
        labelMedium: AppText.label,
        labelSmall: AppText.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: AppText.title,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgSheet,
        contentTextStyle: AppText.body.copyWith(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.neonBlue,
        inactiveTrackColor: AppColors.glassFill,
        thumbColor: AppColors.neonCyan,
        overlayColor: AppColors.neonCyan.withOpacity(0.15),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? AppColors.neonGreen
              : AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? AppColors.neonGreen.withOpacity(0.25)
              : AppColors.glassFill;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.glassBorder),
      ),
    );
  }
}
