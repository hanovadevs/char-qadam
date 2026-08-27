import 'package:flutter/material.dart';

/// Qadam Swiss Style Light Design System.
///
/// Follows the International Typographic Style (Josef Müller-Brockmann, Basel/Zurich):
/// - Clean Pure White (#FFFFFF) & Warm Swiss Beige (#F5F1E8) surfaces
/// - Deep Black (#000000 / #111111) high-contrast typography & solid action buttons
/// - Architectural Grey (#737373 / #808080) for secondary metadata
/// - 1px hairline structural borders (#E5E5E5 / #D4D4D4)
/// - Accent Taupe (#B38B6D) for special badges
/// - Sharp geometric radius (0px to 2px-4px max)
class AppTheme {
  // Swiss Palette Tokens
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFAFAFA);
  static const Color beige = Color(0xFFF5F1E8);
  static const Color beigeDark = Color(0xFFEBE6DC);
  static const Color black = Color(0xFF000000);
  static const Color offBlack = Color(0xFF111111);
  static const Color charcoal = Color(0xFF1F1F1F);

  static const Color grey = Color(0xFF737373);
  static const Color greyMuted = Color(0xFF8C8C8C);
  static const Color greyLight = Color(0xFFF0F0F0);
  static const Color border = Color(0xFFE5E5E5);
  static const Color borderDark = Color(0xFFD4D4D4);

  // Accents
  static const Color taupe = Color(0xFFB38B6D);
  static const Color accentGreen = Color(0xFF16A34A);
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentAmber = Color(0xFFB45309);

  // High contrast action colors
  static const Color primaryColor = Color(0xFF000000);
  static const Color secondaryColor = Color(0xFFB38B6D);

  // Monospace font helper
  static const String monoFont = 'monospace';

  // Base Corner Radius Tokens (Swiss Style: Sharp / Geometric)
  static const double radiusNone = 0.0;
  static const double radiusSm = 2.0;
  static const double radiusMd = 4.0;
  static const double radiusLg = 8.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.light(
        primary: black,
        onPrimary: white,
        secondary: taupe,
        onSecondary: white,
        tertiary: beige,
        surface: white,
        onSurface: offBlack,
        surfaceContainerHighest: beige,
        outline: border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: black,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: black),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        modalBackgroundColor: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusMd)),
          side: BorderSide(color: borderDark, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: offWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: black, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accentRed),
        ),
        labelStyle: const TextStyle(color: grey, fontSize: 13, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: greyMuted, fontSize: 13),
        prefixIconColor: grey,
        suffixIconColor: grey,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: black,
          foregroundColor: white,
          minimumSize: const Size.fromHeight(46),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: black,
          minimumSize: const Size.fromHeight(46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: borderDark, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return black;
            }
            return white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return white;
            }
            return grey;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: border, width: 1),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: black,
        contentTextStyle: const TextStyle(color: white, fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme; // Default to Light Mode as requested
}
