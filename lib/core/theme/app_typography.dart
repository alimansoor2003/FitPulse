import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sora is a variable font, so weights are applied through [FontVariation]
/// as well as [FontWeight] (the latter drives the Cairo fallback used for
/// the Arabic exercise names).
TextStyle sora(
  double size,
  double weight, {
  Color color = AppColors.textPrimary,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'Sora',
    fontFamilyFallback: const <String>['Cairo'],
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontWeight: _weightOf(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight)],
  );
}

/// Arabic-first style for the transliterated exercise names.
TextStyle cairo(
  double size,
  double weight, {
  Color color = AppColors.textSecondary,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Cairo',
    fontSize: size,
    height: height,
    color: color,
    fontWeight: _weightOf(weight),
    fontVariations: <FontVariation>[FontVariation('wght', weight)],
  );
}

FontWeight _weightOf(double weight) {
  final int index = (weight ~/ 100).clamp(1, 9) - 1;
  return FontWeight.values[index];
}

class AppText {
  const AppText._();

  static TextStyle get display => sora(30, 700, height: 1.15, letterSpacing: -0.6);
  static TextStyle get title => sora(22, 600, height: 1.2, letterSpacing: -0.3);
  static TextStyle get section => sora(15, 600, letterSpacing: -0.1);
  static TextStyle get body => sora(14, 400, height: 1.45, color: AppColors.textSecondary);
  static TextStyle get label => sora(12, 500, color: AppColors.textSecondary, letterSpacing: 0.2);
  static TextStyle get caption => sora(11, 400, color: AppColors.textTertiary, letterSpacing: 0.3);
  static TextStyle get metric => sora(26, 700, letterSpacing: -1.0);
  static TextStyle get metricSmall => sora(18, 600, letterSpacing: -0.5);
}
