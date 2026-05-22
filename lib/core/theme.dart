import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgriColors {
  AgriColors._();

  static const Color primary = Color(0xFF00E676);
  static const Color secondary = Color(0xFFFFAB00);
  static const Color tertiary = Color(0xFFFFBA79);

  static const Color primaryLight = Color(0xFF69F0AE);
  static const Color primaryDark = Color(0xFF00B248);

  static const Color secondaryLight = Color(0xFFFFD54F);
  static const Color secondaryDark = Color(0xFFFF6F00);

  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB00);
  static const Color danger = Color(0xFFFF5252);
  static const Color info = Color(0xFF40C4FF);

  static const Color drought = Color(0xFFFFAB00);
  static const Color flood = Color(0xFF40C4FF);
  static const Color heat = Color(0xFFFF5252);
  static const Color blight = Color(0xFFFFBA79);

  static const Color backgroundDark = Color(0xFF0A0F0D);
  static const Color backgroundCard = Color(0xFF111A14);
  static const Color backgroundSurface = Color(0xFF162118);

  static const Color textPrimary = Color(0xFFEEF7F0);
  static const Color textSecondary = Color(0xFF8FA896);
  static const Color textHint = Color(0xFF4A5E50);

  static const Color border = Color(0xFF1E2E22);
  static const Color borderLight = Color(0xFF2A3F2E);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Light-mode tokens
  static const Color backgroundLight = Color(0xFFF7F6F3);
  static const Color backgroundCardLight = Color(0xFFFFFFFF);
  static const Color backgroundSurfaceLight = Color(0xFFF2F2F0);
  static const Color textPrimaryLight = Color(0xFF1F1E1C);
  static const Color textSecondaryLight = Color(0xFF6B6B6B);

  static const Color paleRed = Color(0xFFFDEBEC);
  static const Color paleBlue = Color(0xFFE1F3FE);
  static const Color paleGreen = Color(0xFFEDF3EC);
  static const Color paleYellow = Color(0xFFFBF3DB);

  static Color forAlertType(String type) {
    switch (type.toLowerCase()) {
      case 'drought':
        return drought;
      case 'flood':
        return flood;
      case 'heat':
        return heat;
      case 'blight':
        return blight;
      default:
        return primary;
    }
  }
}

class AgriTheme {
  AgriTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.newsreader(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        height: 1.0,
        letterSpacing: -0.04,
        color: AgriColors.textPrimaryLight,
      ),
      displayMedium: GoogleFonts.newsreader(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.02,
        letterSpacing: -0.04,
        color: AgriColors.textPrimaryLight,
      ),
      displaySmall: GoogleFonts.newsreader(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.05,
        letterSpacing: -0.03,
        color: AgriColors.textPrimaryLight,
      ),
      headlineLarge: GoogleFonts.newsreader(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.08,
        letterSpacing: -0.03,
        color: AgriColors.textPrimaryLight,
      ),
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.025,
        color: AgriColors.textPrimaryLight,
      ),
      headlineSmall: GoogleFonts.newsreader(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.02,
        color: AgriColors.textPrimaryLight,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.01,
        color: AgriColors.textPrimaryLight,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AgriColors.textPrimaryLight,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AgriColors.textPrimaryLight,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: AgriColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: AgriColors.textPrimary,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AgriColors.textSecondaryLight,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
        color: AgriColors.textPrimaryLight,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
        color: AgriColors.textSecondaryLight,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
        color: AgriColors.textSecondaryLight,
      ),
    );

    final scheme = ColorScheme.light(
      primary: AgriColors.primary,
      onPrimary: AgriColors.white,
      secondary: AgriColors.info,
      onSecondary: AgriColors.white,
      tertiary: AgriColors.warning,
      onTertiary: AgriColors.white,
      surface: AgriColors.backgroundCardLight,
      onSurface: AgriColors.textPrimaryLight,
      // background: AgriColors.backgroundLight, // Deprecated
      // onBackground: AgriColors.textPrimaryLight, // Deprecated
      error: AgriColors.danger,
      onError: AgriColors.white,
      outline: AgriColors.border,
      outlineVariant: AgriColors.borderLight,
    );

    return base.copyWith(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AgriColors.backgroundLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AgriColors.backgroundLight,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AgriColors.textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AgriColors.backgroundCardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AgriColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AgriColors.backgroundCardLight,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AgriColors.textHint),
        labelStyle: textTheme.labelMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriColors.primary, width: 1.25),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgriColors.primary,
          foregroundColor: AgriColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: textTheme.labelLarge?.copyWith(
            color: AgriColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AgriColors.textPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AgriColors.textPrimary,
          side: const BorderSide(color: AgriColors.border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AgriColors.primary,
          foregroundColor: AgriColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AgriColors.backgroundSurfaceLight,
        selectedColor: AgriColors.paleBlue,
        disabledColor: AgriColors.backgroundSurfaceLight,
        secondarySelectedColor: AgriColors.paleGreen,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelSmall?.copyWith(
          color: AgriColors.textPrimaryLight,
        ),
        side: const BorderSide(color: AgriColors.border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AgriColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AgriColors.textSecondaryLight, size: 22),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AgriColors.backgroundCardLight,
        indicatorColor: AgriColors.paleBlue,
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AgriColors.textPrimaryLight,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AgriColors.textSecondaryLight,
        ),
        selectedIconTheme: const IconThemeData(color: AgriColors.textPrimary),
        unselectedIconTheme: const IconThemeData(
          color: AgriColors.textSecondaryLight,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AgriColors.backgroundCardLight,
        selectedItemColor: AgriColors.textPrimaryLight,
        unselectedItemColor: AgriColors.textSecondaryLight,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AgriColors.backgroundCardLight,
        indicatorColor: AgriColors.paleBlue,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? AgriColors.textPrimaryLight : AgriColors.textSecondaryLight,
            size: 22,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AgriColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AgriColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AgriColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: AgriColors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AgriColors.primary,
        linearTrackColor: AgriColors.borderLight,
        circularTrackColor: AgriColors.borderLight,
      ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );
  }
  
  // Dark theme (previously the primary theme implementation)
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.newsreader(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        height: 1.0,
        letterSpacing: -0.04,
        color: AgriColors.textPrimary,
      ),
      displayMedium: GoogleFonts.newsreader(
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.02,
        letterSpacing: -0.04,
        color: AgriColors.textPrimary,
      ),
      displaySmall: GoogleFonts.newsreader(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.05,
        letterSpacing: -0.03,
        color: AgriColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.newsreader(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.08,
        letterSpacing: -0.03,
        color: AgriColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.newsreader(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.025,
        color: AgriColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.newsreader(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.02,
        color: AgriColors.textPrimary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.01,
        color: AgriColors.textPrimary,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AgriColors.textPrimary,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: AgriColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: AgriColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: AgriColors.textPrimary,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AgriColors.textSecondary,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
        color: AgriColors.textPrimary,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
        color: AgriColors.textSecondary,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
        color: AgriColors.textSecondary,
      ),
    );

    final scheme = const ColorScheme.dark(
      primary: AgriColors.primary,
      onPrimary: AgriColors.white,
      secondary: AgriColors.info,
      onSecondary: AgriColors.white,
      tertiary: AgriColors.warning,
      onTertiary: AgriColors.white,
      surface: AgriColors.backgroundCard,
      onSurface: AgriColors.textPrimary,
      error: AgriColors.danger,
      onError: AgriColors.white,
      outline: AgriColors.border,
      outlineVariant: AgriColors.borderLight,
      surfaceContainerHighest: AgriColors.backgroundSurface,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AgriColors.backgroundDark,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AgriColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AgriColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AgriColors.backgroundCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AgriColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AgriColors.backgroundCard,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AgriColors.textHint),
        labelStyle: textTheme.labelMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriColors.primary, width: 1.25),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgriColors.primary,
          foregroundColor: AgriColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: textTheme.labelLarge?.copyWith(
            color: AgriColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AgriColors.textPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AgriColors.textPrimary,
          side: const BorderSide(color: AgriColors.border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AgriColors.primary,
          foregroundColor: AgriColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AgriColors.backgroundSurface,
        selectedColor: AgriColors.paleBlue,
        disabledColor: AgriColors.backgroundSurface,
        secondarySelectedColor: AgriColors.paleGreen,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelSmall?.copyWith(
          color: AgriColors.textPrimary,
        ),
        side: const BorderSide(color: AgriColors.border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AgriColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AgriColors.textSecondary, size: 22),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AgriColors.backgroundCard,
        indicatorColor: AgriColors.paleBlue,
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AgriColors.textPrimary,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: AgriColors.textSecondary,
        ),
        selectedIconTheme: const IconThemeData(color: AgriColors.textPrimary),
        unselectedIconTheme: const IconThemeData(
          color: AgriColors.textSecondary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AgriColors.backgroundCard,
        selectedItemColor: AgriColors.textPrimary,
        unselectedItemColor: AgriColors.textSecondary,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AgriColors.backgroundCard,
        indicatorColor: AgriColors.paleBlue,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? AgriColors.textPrimary : AgriColors.textSecondary,
            size: 22,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AgriColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AgriColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AgriColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: AgriColors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AgriColors.primary,
        linearTrackColor: AgriColors.borderLight,
        circularTrackColor: AgriColors.borderLight,
      ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

