import 'package:flutter/material.dart';

/// Stepsy: an everyday walking club in the established mint/teal palette.
///
/// Shared type, surface and control tokens:
/// - Light theme only (pure white and near-white/muted surfaces)
/// - Single brand accent palette (Teal: #2FE0C4, #0B4A47, #0F8A78)
/// - Dark navy-charcoal typography (#16213A, never pure black)
/// - 1px hairline structural borders and dividers (#E7EBEA)
/// - Continuous squircle curves (16-20pt card radius, 10-14pt controls)
/// - iOS typography scale with sentence case
class AppTheme {
  static const String bodyFont = 'Manrope';
  static const String displayFont = 'SpaceGrotesk';
  static const Color mintWash = Color(0xFFE8F6F2);
  static const Color onDeep = Color(0xFFDAF7EE);
  static const Color walkerSkin = Color(0xFFF1C9A7);
  static const Duration motion = Duration(milliseconds: 220);
  static const Curve easeOut = Curves.easeOutCubic;
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
  // Stepsy Core Brand Palette Tokens
  static const Color accentBright = Color(
    0xFF2FE0C4,
  ); // Gradient start (hero moments)
  static const Color accentDeep = Color(0xFF0B4A47); // Gradient end
  static const Color accentSolid = Color(
    0xFF087F72,
  ); // Primary buttons, active tabs, text links

  static const Color inkPrimary = Color(
    0xFF102B32,
  ); // Primary text: dark navy-charcoal, NOT pure black
  static const Color inkSecondary = Color(
    0xFF536B71,
  ); // Secondary text, inactive icons
  static const Color inkTertiary = Color(
    0xFF9AA3AD,
  ); // Placeholders, disabled states, timestamps

  static const Color surface = Color(
    0xFFFFFFFF,
  ); // Cards, modals, primary content
  static const Color surfaceMuted = Color(
    0xFFFAFBF8,
  ); // Grouped list backgrounds, subtle fills
  static const Color hairline = Color(
    0xFFDDE8E3,
  ); // 1px dividers, card outlines (never black)

  static const Color destructive = Color(
    0xFFB43837,
  ); // Strictly reserved for account deletion

  // Backward-compatibility aliases (mapped directly to Stepsy brand tokens)
  static const Color black = inkPrimary;
  static const Color offBlack = inkPrimary;
  static const Color charcoal = inkPrimary;
  static const Color white = surface;
  static const Color offWhite = surfaceMuted;
  static const Color beige = surfaceMuted;
  static const Color beigeDark = hairline;
  static const Color grey = inkSecondary;
  static const Color greyMuted = inkTertiary;
  static const Color greyLight = surfaceMuted;
  static const Color border = hairline;
  static const Color borderDark = hairline;
  static const Color taupe = accentSolid;
  static const Color accentGreen = accentSolid;
  static const Color accentRed = destructive;
  static const Color accentAmber = Color(0xFFD97706);
  static const Color primaryColor = accentSolid;
  static const Color secondaryColor = accentSolid;
  static const String monoFont = displayFont;

  // Corner Radius Tokens (Apple Continuous Squircle Language)
  static const double radiusNone = 0.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 24.0;
  static const double radiusPill = 999.0;

  // Typography Constants (iOS Native Type Scale)
  static const TextStyle largeTitleStyle = TextStyle(
    fontFamily: displayFont,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: inkPrimary,
  );

  static const TextStyle titleStyle = TextStyle(
    fontFamily: displayFont,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: inkPrimary,
  );

  static const TextStyle headlineStyle = TextStyle(
    fontFamily: displayFont,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: inkPrimary,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: bodyFont,
    height: 1.5,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: inkPrimary,
  );

  static const TextStyle captionStyle = TextStyle(
    fontFamily: bodyFont,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: inkSecondary,
  );

  static const TextStyle heroNumeralStyle = TextStyle(
    fontFamily: displayFont,
    fontFeatures: tabular,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    color: inkPrimary,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surfaceMuted,
      fontFamily: bodyFont,
      textTheme: const TextTheme(
        displayLarge: heroNumeralStyle,
        headlineLarge: largeTitleStyle,
        titleLarge: titleStyle,
        titleMedium: headlineStyle,
        bodyLarge: bodyStyle,
        bodyMedium: bodyStyle,
        bodySmall: captionStyle,
      ),
      colorScheme: const ColorScheme.light(
        primary: accentDeep,
        onPrimary: surface,
        secondary: accentSolid,
        onSecondary: surface,
        tertiary: accentBright,
        surface: surface,
        onSurface: inkPrimary,
        surfaceContainerHighest: surfaceMuted,
        outline: hairline,
        error: destructive,
        onError: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceMuted,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: inkPrimary,
          fontFamily: displayFont,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: inkPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: hairline, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: hairline, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accentSolid, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: destructive, width: 1),
        ),
        labelStyle: const TextStyle(
          fontFamily: bodyFont,
          color: inkSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: const TextStyle(
          fontFamily: bodyFont,
          color: inkTertiary,
          fontSize: 14,
        ),
        prefixIconColor: inkSecondary,
        suffixIconColor: inkSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentDeep,
          foregroundColor: surface,
          minimumSize: const Size(0, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: hairline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return surface;
            }
            return surfaceMuted;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return inkPrimary;
            }
            return inkSecondary;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Colors.transparent, width: 0),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: bodyFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFont,
          color: surface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme; // Light theme only
}
