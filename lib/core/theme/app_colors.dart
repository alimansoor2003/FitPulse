import 'package:flutter/material.dart';

/// The FitPulse palette: deep navy ground, translucent glass, neon blue/cyan.
class AppColors {
  const AppColors._();

  // Backgrounds
  static const Color bgDeep = Color(0xFF0B111E);
  static const Color bgElevated = Color(0xFF0D1527);
  static const Color bgSheet = Color(0xFF111A2D);

  // Glass
  static const Color glassFill = Color(0x14FFFFFF); // white @ 8%
  static const Color glassFillStrong = Color(0x1FFFFFFF); // white @ 12%
  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color glassBorderBright = Color(0x33FFFFFF);

  /// Fully opaque panel colour for surfaces that float *above* scrolling
  /// content (bottom nav, rest timer, modal sheets). These must not be
  /// translucent or the list scrolling underneath shows through the text.
  static const Color surfaceOpaque = Color(0xFF161F33);
  static const Color surfaceOpaqueRaised = Color(0xFF1B2540);

  // Accents
  static const Color neonBlue = Color(0xFF0088FF);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF22E58A);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF4D6A);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF93A6C4);
  static const Color textTertiary = Color(0xFF5D6E8A);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[neonBlue, neonCyan],
  );

  // Slightly stronger than before now that GlassCard no longer blurs what's
  // behind it (see glass_card.dart) - keeps the same visual separation from
  // the aurora background without needing a live backdrop blur.
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x24FFFFFF), Color(0x14FFFFFF)],
  );

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF0D1527), Color(0xFF0B111E)],
  );
}
