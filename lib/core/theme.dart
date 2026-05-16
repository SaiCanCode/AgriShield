import 'package:flutter/material.dart';


//  AgriShield Color Palette
class AgriColors {
  AgriColors._();

  // Brand
  static const Color primary    = Color(0xFF00E676); // green
  static const Color secondary  = Color(0xFFFFAB00); // amber
  static const Color tertiary   = Color(0xFFFFBA79); // peach

  // Primary shades
  static const Color primaryLight  = Color(0xFF69F0AE);
  static const Color primaryDark   = Color(0xFF00B248);

  // Secondary shades
  static const Color secondaryLight = Color(0xFFFFD54F);
  static const Color secondaryDark  = Color(0xFFFF6F00);

  // Semantic
  static const Color success  = Color(0xFF00E676);
  static const Color warning  = Color(0xFFFFAB00);
  static const Color danger   = Color(0xFFFF5252);
  static const Color info     = Color(0xFF40C4FF);

  // Alert type colors
  static const Color drought  = Color(0xFFFFAB00); // amber
  static const Color flood    = Color(0xFF40C4FF); // blue
  static const Color heat     = Color(0xFFFF5252); // red
  static const Color blight   = Color(0xFFFFBA79); // peach
 

  // Backgrounds
  static const Color backgroundDark    = Color(0xFF0A0F0D);
  static const Color backgroundCard    = Color(0xFF111A14);
  static const Color backgroundSurface = Color(0xFF162118);

  // Text
  static const Color textPrimary   = Color(0xFFEEF7F0);
  static const Color textSecondary = Color(0xFF8FA896);
  static const Color textHint      = Color(0xFF4A5E50);

  // Border
  static const Color border        = Color(0xFF1E2E22);
  static const Color borderLight   = Color(0xFF2A3F2E);

  // Utility
  static const Color white         = Color(0xFFFFFFFF);
  static const Color black         = Color(0xFF000000);
  static const Color transparent   = Colors.transparent;

  // Maps alert type string (from Firebase) to its display color
  static Color forAlertType(String type) {
    switch (type.toLowerCase()) {
      case 'drought':   return drought;
      case 'flood':     return flood;
      case 'heat':      return heat;
      case 'blight':    return blight;
      default:          return primary;
    }
  }
}





//  AgriShield ThemeData
class AgriTheme {
  AgriTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Outfit', // change to 'Lato' if preferred

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary:          AgriColors.primary,
        secondary:        AgriColors.secondary,
        tertiary:         AgriColors.tertiary,
        surface:          AgriColors.backgroundCard,
        error:            AgriColors.danger,
        onPrimary:        AgriColors.black,
        onSecondary:      AgriColors.black,
        onSurface:        AgriColors.textPrimary,
        onError:          AgriColors.white,
      ),

      scaffoldBackgroundColor: AgriColors.backgroundDark,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AgriColors.backgroundDark,
        foregroundColor: AgriColors.textPrimary,
        elevation:       0,
        centerTitle:     false,
      ),

      // Cards
      cardTheme: CardThemeData(
        color:        AgriColors.backgroundCard,
        elevation:    0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AgriColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AgriColors.backgroundSurface,
        hintStyle:   const TextStyle(color: AgriColors.textHint),
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
          borderSide: const BorderSide(color: AgriColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:   AgriColors.primary,
          foregroundColor:   AgriColors.black,
          minimumSize:       const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily:  'Outfit',
            fontSize:    16,
            fontWeight:  FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color:     AgriColors.border,
        thickness: 1,
        space:     1,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: AgriColors.textSecondary,
        size:  22,
      ),

      // Side Nav
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AgriColors.backgroundCard,
        indicatorColor: AgriColors.primary.withValues(alpha: 0.15),
        selectedLabelTextStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AgriColors.primary,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AgriColors.textSecondary,
        ),
        selectedIconTheme: const IconThemeData(color: AgriColors.primary),
        unselectedIconTheme: const IconThemeData(color: AgriColors.textSecondary),
      ),
    );
  }
}
