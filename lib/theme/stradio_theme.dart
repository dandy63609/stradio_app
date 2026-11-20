import 'package:flutter/material.dart';

/// STRADIO Daylight Instrument Minimalism Design Tokens (`docs/DESIGN.md`).
///
/// Dials: ENERGY 1 / RHYTHM 2 / MOTION 2.
/// Fixed Daylight palette verified >= WCAG AA across all text pairings:
/// - Midnight (#191923) on Warm Ivory (#F5F0E8): 15.37:1 (AAA)
/// - Text Secondary (#625D72) on Warm Ivory (#F5F0E8): 5.56:1 (AA)
/// - Deep Coral (#B53D28) on Warm Ivory (#F5F0E8): 5.05:1 (AA)
/// - Twilight Plum (#46509E) on Warm Ivory (#F5F0E8): 6.38:1 (AA)
class StradioColors {
  const StradioColors._();

  // --- Daylight Surfaces ---
  static const Color warmIvory = Color(0xFFF5F0E8);
  static const Color surfaceBase = warmIvory;
  static const Color surfaceRecessed = Color(0xFFEAE4DC);
  static const Color surfaceCard = Color(0xFFFAF7F2);
  static const Color surfaceGlass = Color(0xB8FAF7F2); // rgba(250,247,242,0.72)
  static const Color surfaceGlassRim = Color(0xA6FFFFFF); // rgba(255,255,255,0.65)
  static const Color frostedPod = Color(0x73FFFFFF); // rgba(255,255,255,0.45)

  // --- Structure & Typography ---
  static const Color midnight = Color(0xFF191923);
  static const Color textPrimary = midnight;
  static const Color textSecondary = Color(0xFF625D72);
  static const Color textOnDark = warmIvory;
  static const Color borderSubtle = Color(0xFFDFD9CE);

  // --- Sonic Accents ---
  static const Color sonicCoral = Color(0xFFFF765F);
  static const Color textAccentDeep = Color(0xFFB53D28);
  static const Color rhythmViolet = Color(0xFFA995DB);
  static const Color twilightPlum = Color(0xFF46509E);

  // --- Soft Kinetic Blooms ---
  static const Color glowCoralSoft = Color(0x24FF765F);
  static const Color glowVioletSoft = Color(0x24A995DB);

  // --- Semantic Status ---
  static const Color statusLive = Color(0xFF2EBF6F);
  static const Color statusPaused = Color(0xFFD97706);
  static const Color statusError = textAccentDeep;
}

class StradioRadii {
  const StradioRadii._();

  static const double sm = 4.0;
  static const double md = 12.0;
  static const double lg = 20.0;
  static const double tray = 24.0;
  static const double xl = 28.0;
  static const double full = 9999.0;
}

class StradioSpacing {
  const StradioSpacing._();

  static const double s1 = 4.0;
  static const double s2 = 8.0;
  static const double s3 = 12.0;
  static const double s4 = 16.0;
  static const double s5 = 20.0;
  static const double s6 = 24.0;
  static const double s8 = 32.0;
  static const double s10 = 40.0;
  static const double s12 = 48.0;
}

/// Exact typographic ramp from `docs/DESIGN.md` (Sora 500/600 + Inter 400/500).
class StradioTypography {
  const StradioTypography._();

  static const List<String> _fallback = ['Roboto', 'sans-serif'];

  static TextStyle titlePrimary({Color color = StradioColors.textPrimary}) =>
      TextStyle(
        fontFamily: 'Sora',
        fontFamilyFallback: _fallback,
        fontWeight: FontWeight.w600,
        fontSize: 28,
        height: 32 / 28,
        letterSpacing: -0.56,
        color: color,
      );

  static TextStyle titleMuted({
    Color color = StradioColors.textSecondary,
    double fontSize = 28,
  }) =>
      TextStyle(
        fontFamily: 'Sora',
        fontFamilyFallback: _fallback,
        fontWeight: FontWeight.w500,
        fontSize: fontSize,
        height: 32 / 28,
        letterSpacing: -0.56,
        color: color,
      );

  static TextStyle metricHero({
    Color color = StradioColors.textPrimary,
    double fontSize = 44,
  }) => TextStyle(
    fontFamily: 'Sora',
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w500,
    fontSize: fontSize,
    height: 48 / 44,
    letterSpacing: -1.32,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle metricValue({
    Color color = StradioColors.textPrimary,
    double fontSize = 28,
  }) => TextStyle(
    fontFamily: 'Sora',
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w500,
    fontSize: fontSize,
    height: 32 / 28,
    letterSpacing: -0.56,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle headingSmall({
    Color color = StradioColors.textPrimary,
    double fontSize = 18,
  }) => TextStyle(
    fontFamily: 'Sora',
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w600,
    fontSize: fontSize,
    height: 1.3,
    letterSpacing: -0.2,
    color: color,
  );

  static TextStyle metricLabel({Color color = StradioColors.textSecondary}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: _fallback,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.0,
        color: color,
      );

  static TextStyle microCap({Color color = StradioColors.textSecondary}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: _fallback,
        fontWeight: FontWeight.w500,
        fontSize: 11,
        height: 14 / 11,
        letterSpacing: 0.44,
        color: color,
      );

  static TextStyle body({
    Color color = StradioColors.textSecondary,
    double fontSize = 14,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: _fallback,
    fontWeight: FontWeight.w400,
    fontSize: fontSize,
    height: 20 / 14,
    letterSpacing: 0.0,
    color: color,
  );

  static TextStyle buttonLabel({Color color = StradioColors.textOnDark}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: _fallback,
        fontWeight: FontWeight.w500,
        fontSize: 15,
        height: 20 / 15,
        letterSpacing: 0.0,
        color: color,
      );

  static TextStyle pillBadge({Color color = StradioColors.textPrimary}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: _fallback,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 16 / 13,
        letterSpacing: 0.0,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

class StradioTheme {
  const StradioTheme._();

  static ThemeData get daylightTheme {
    const colorScheme = ColorScheme.light(
      primary: StradioColors.midnight,
      onPrimary: StradioColors.textOnDark,
      secondary: StradioColors.twilightPlum,
      onSecondary: StradioColors.textOnDark,
      tertiary: StradioColors.sonicCoral,
      surface: StradioColors.surfaceCard,
      onSurface: StradioColors.textPrimary,
      surfaceContainerLow: StradioColors.surfaceBase,
      surfaceContainer: StradioColors.surfaceRecessed,
      outline: StradioColors.borderSubtle,
      error: StradioColors.statusError,
      onError: StradioColors.textOnDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: StradioColors.warmIvory,
      fontFamily: 'Inter',
      splashFactory: InkSparkle.splashFactory,
      dividerColor: StradioColors.borderSubtle,
      appBarTheme: const AppBarTheme(
        backgroundColor: StradioColors.warmIvory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: StradioColors.textPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StradioColors.midnight,
          foregroundColor: StradioColors.textOnDark,
          minimumSize: const Size(48, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StradioRadii.full),
          ),
          textStyle: StradioTypography.buttonLabel(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StradioColors.textPrimary,
          backgroundColor: StradioColors.surfaceCard,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: StradioColors.borderSubtle),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StradioRadii.full),
          ),
          textStyle: StradioTypography.buttonLabel(
            color: StradioColors.textPrimary,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? StradioColors.surfaceCard
              : StradioColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? StradioColors.midnight
              : StradioColors.surfaceRecessed,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(
          StradioColors.borderSubtle,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: StradioColors.midnight,
        contentTextStyle: StradioTypography.body(
          color: StradioColors.textOnDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StradioRadii.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Alias retained for any callers referencing `lightTheme`.
  static ThemeData get lightTheme => daylightTheme;
}
