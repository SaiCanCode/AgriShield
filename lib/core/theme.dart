import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgriColors {
  AgriColors._();

  // ── Brand accent (single green) ──────────────────────────────────────────
  static const Color primary      = Color(0xFF00E676);
  static const Color primaryLight = Color(0xFF69F0AE);
  static const Color primaryDark  = Color(0xFF00B248);

  // ── Secondary / alert accents ────────────────────────────────────────────
  static const Color secondary    = Color(0xFFFFAB00);
  static const Color tertiary     = Color(0xFFFFBA79);

  static const Color secondaryLight = Color(0xFFFFD54F);
  static const Color secondaryDark  = Color(0xFFFF6F00);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF00E676);
  static const Color warning  = Color(0xFFFFAB00);
  static const Color danger   = Color(0xFFFF5252);
  static const Color info     = Color(0xFF40C4FF);

  // ── Alert type colours ────────────────────────────────────────────────────
  static const Color drought  = Color(0xFFFFAB00);
  static const Color flood    = Color(0xFF40C4FF);
  static const Color heat     = Color(0xFFFF5252);
  static const Color blight   = Color(0xFFFFBA79);

  // ── Dark mode surfaces (neutral — no green tint) ─────────────────────────
  static const Color backgroundDark    = Color(0xFF0C0C0C); // near-black
  static const Color backgroundCard    = Color(0xFF161616); // card surface
  static const Color backgroundSurface = Color(0xFF1E1E1E); // elevated surface

  // ── Dark mode text ────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF2F2F2); // clean white
  static const Color textSecondary = Color(0xFF8A8A8A); // neutral grey
  static const Color textHint      = Color(0xFF4A4A4A); // dimmed

  // ── Dark mode borders ─────────────────────────────────────────────────────
  static const Color border      = Color(0xFF242424);
  static const Color borderLight = Color(0xFF2E2E2E);

  // ── Light mode surfaces ───────────────────────────────────────────────────
  static const Color backgroundLight        = Color(0xFFF7F6F3);
  static const Color backgroundCardLight    = Color(0xFFFFFFFF);
  static const Color backgroundSurfaceLight = Color(0xFFF2F2F0);
  static const Color textPrimaryLight       = Color(0xFF1F1E1C);
  static const Color textSecondaryLight     = Color(0xFF6B6B6B);

  // ── Pale tints (chips / highlights) ──────────────────────────────────────
  static const Color paleRed    = Color(0xFFFDEBEC);
  static const Color paleBlue   = Color(0xFFE1F3FE);
  static const Color paleGreen  = Color(0xFFEDF3EC);
  static const Color paleYellow = Color(0xFFFBF3DB);

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const Color white       = Color(0xFFFFFFFF);
  static const Color black       = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  static Color forAlertType(String type) {
    switch (type.toLowerCase()) {
      case 'drought': return drought;
      case 'flood':   return flood;
      case 'heat':    return heat;
      case 'blight':  return blight;
      default:        return primary;
    }
  }
}

class AgriTheme {
  AgriTheme._();

  // ── Shared text theme builder ─────────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary) {
    return GoogleFonts.manropeTextTheme(base).copyWith(
      displayLarge: GoogleFonts.newsreader(
        fontSize: 56, fontWeight: FontWeight.w600,
        height: 1.0, letterSpacing: -0.04, color: primary,
      ),
      displayMedium: GoogleFonts.newsreader(
        fontSize: 44, fontWeight: FontWeight.w600,
        height: 1.02, letterSpacing: -0.04, color: primary,
      ),
      displaySmall: GoogleFonts.newsreader(
        fontSize: 36, fontWeight: FontWeight.w600,
        height: 1.05, letterSpacing: -0.03, color: primary,
      ),
      headlineLarge: GoogleFonts.newsreader(
        fontSize: 32, fontWeight: FontWeight.w600,
        height: 1.08, letterSpacing: -0.03, color: primary,
      ),
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 28, fontWeight: FontWeight.w600,
        height: 1.1, letterSpacing: -0.025, color: primary,
      ),
      headlineSmall: GoogleFonts.newsreader(
        fontSize: 24, fontWeight: FontWeight.w600,
        height: 1.1, letterSpacing: -0.02, color: primary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18, fontWeight: FontWeight.w600,
        height: 1.2, letterSpacing: -0.01, color: primary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w600,
        height: 1.25, color: primary,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w600,
        height: 1.25, color: primary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16, fontWeight: FontWeight.w400,
        height: 1.6, color: primary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w400,
        height: 1.6, color: primary,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w400,
        height: 1.5, color: secondary,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14, fontWeight: FontWeight.w600,
        letterSpacing: 0.02, color: primary,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12, fontWeight: FontWeight.w600,
        letterSpacing: 0.05, color: secondary,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11, fontWeight: FontWeight.w600,
        letterSpacing: 0.05, color: secondary,
      ),
    );
  }

  // ── LIGHT ─────────────────────────────────────────────────────────────────
  static ThemeData get light {
    final base     = ThemeData.light(useMaterial3: true);
    final textTheme = _buildTextTheme(
      base.textTheme,
      AgriColors.textPrimaryLight,
      AgriColors.textSecondaryLight,
    );

    final scheme = ColorScheme.light(
      primary:    AgriColors.primary,
      onPrimary:  AgriColors.white,
      secondary:  AgriColors.info,
      onSecondary: AgriColors.white,
      tertiary:   AgriColors.warning,
      onTertiary: AgriColors.white,
      surface:    AgriColors.backgroundCardLight,
      onSurface:  AgriColors.textPrimaryLight,
      error:      AgriColors.danger,
      onError:    AgriColors.white,
      outline:    AgriColors.border,
      outlineVariant: AgriColors.borderLight,
    );

    return _buildTheme(
      base:        base,
      scheme:      scheme,
      textTheme:   textTheme,
      scaffoldBg:  AgriColors.backgroundLight,
      appBarBg:    AgriColors.backgroundLight,
      cardColor:   AgriColors.backgroundCardLight,
      inputFill:   AgriColors.backgroundCardLight,
      chipBg:      AgriColors.backgroundSurfaceLight,
    );
  }

  // ── DARK ──────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base      = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(
      base.textTheme,
      AgriColors.textPrimary,
      AgriColors.textSecondary,
    );

    const scheme = ColorScheme.dark(
      primary:     AgriColors.primary,
      onPrimary:   AgriColors.black,
      secondary:   AgriColors.info,
      onSecondary: AgriColors.white,
      tertiary:    AgriColors.warning,
      onTertiary:  AgriColors.black,
      // Neutral dark surfaces — no green tint
      surface:     AgriColors.backgroundCard,
      onSurface:   AgriColors.textPrimary,
      surfaceContainerHighest: AgriColors.backgroundSurface,
      error:       AgriColors.danger,
      onError:     AgriColors.white,
      outline:     AgriColors.border,
      outlineVariant: AgriColors.borderLight,
    );

    return _buildTheme(
      base:        base,
      scheme:      scheme,
      textTheme:   textTheme,
      scaffoldBg:  AgriColors.backgroundDark,
      appBarBg:    AgriColors.backgroundDark,
      cardColor:   AgriColors.backgroundCard,
      inputFill:   AgriColors.backgroundCard,
      chipBg:      AgriColors.backgroundSurface,
    );
  }

  // ── Shared builder ────────────────────────────────────────────────────────
  static ThemeData _buildTheme({
    required ThemeData      base,
    required ColorScheme    scheme,
    required TextTheme      textTheme,
    required Color          scaffoldBg,
    required Color          appBarBg,
    required Color          cardColor,
    required Color          inputFill,
    required Color          chipBg,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    return base.copyWith(
      brightness:              scheme.brightness,
      colorScheme:             scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme:               textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor:  appBarBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor:  scheme.onSurface,
        elevation:        0,
        centerTitle:      false,
        titleTextStyle:   textTheme.titleLarge,
      ),

      cardTheme: CardThemeData(
        color:            cardColor,
        elevation:        0,
        margin:           EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AgriColors.border : AgriColors.border,
            width: 1,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: inputFill,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AgriColors.textHint : AgriColors.textHint,
        ),
        labelStyle: textTheme.labelMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriColors.primary, width: 1.25),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgriColors.primary,
          foregroundColor: isDark ? AgriColors.black : AgriColors.white,
          minimumSize:     const Size.fromHeight(52),
          elevation:       0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          textStyle:       textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          minimumSize:     const Size.fromHeight(52),
          elevation:       0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AgriColors.primary,
          foregroundColor: isDark ? AgriColors.black : AgriColors.white,
          minimumSize:     const Size.fromHeight(52),
          elevation:       0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor:         chipBg,
        selectedColor:           isDark
            ? AgriColors.primary.withValues(alpha: 0.15)
            : AgriColors.paleGreen,
        disabledColor:           chipBg,
        secondarySelectedColor:  isDark
            ? AgriColors.primary.withValues(alpha: 0.15)
            : AgriColors.paleBlue,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelSmall?.copyWith(color: scheme.onSurface),
        side: BorderSide(color: scheme.outline, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),

      dividerTheme: DividerThemeData(
        color:     scheme.outline,
        thickness: 1,
        space:     1,
      ),

      iconTheme: IconThemeData(
        color: isDark ? AgriColors.textSecondary : AgriColors.textSecondaryLight,
        size:  22,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardColor,
        indicatorColor:  isDark
            ? AgriColors.primary.withValues(alpha: 0.15)
            : AgriColors.paleBlue,
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: isDark ? AgriColors.textSecondary : AgriColors.textSecondaryLight,
        ),
        selectedIconTheme:   IconThemeData(color: scheme.onSurface),
        unselectedIconTheme: IconThemeData(
          color: isDark ? AgriColors.textSecondary : AgriColors.textSecondaryLight,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      cardColor,
        selectedItemColor:    scheme.onSurface,
        unselectedItemColor:  isDark
            ? AgriColors.textSecondary
            : AgriColors.textSecondaryLight,
        selectedLabelStyle:   textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor:  isDark
            ? AgriColors.primary.withValues(alpha: 0.15)
            : AgriColors.paleBlue,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active
                ? scheme.onSurface
                : (isDark
                    ? AgriColors.textSecondary
                    : AgriColors.textSecondaryLight),
            size: 22,
          );
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AgriColors.backgroundSurface : AgriColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AgriColors.textPrimary : AgriColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color:        isDark ? AgriColors.backgroundSurface : AgriColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: isDark ? AgriColors.textPrimary : AgriColors.white,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color:             AgriColors.primary,
        linearTrackColor:  scheme.outline,
        circularTrackColor: scheme.outline,
      ),

      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}