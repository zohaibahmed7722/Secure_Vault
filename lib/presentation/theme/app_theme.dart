import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brandColor = Color(0xFF5146E5);
  static const accentColor = Color(0xFF0F9F8F);
  static const backgroundColor = Color(0xFFFFFFFF);

  static Color? parseHexColor(String value) {
    final hex = value.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return Color(int.parse('FF$hex', radix: 16));
  }

  static String hexColor(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  static Color secondaryFor(Color primaryColor, {bool dark = false}) {
    if (primaryColor == brandColor) {
      return dark ? const Color(0xFF55D6C2) : accentColor;
    }
    final hsv = HSVColor.fromColor(primaryColor);
    final shiftedHue = (hsv.hue + 28) % 360;
    return HSVColor.fromAHSV(
      1.0,
      shiftedHue,
      dark ? (hsv.saturation * 0.75).clamp(0.25, 0.85) : hsv.saturation,
      dark ? 0.92 : (hsv.value * 0.95).clamp(0.45, 0.95),
    ).toColor();
  }

  static ThemeData get light => lightWithColor(brandColor);

  static ThemeData lightWithColor(Color primaryColor) {
    final secondary = secondaryFor(primaryColor, dark: false);
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: backgroundColor,
    ).copyWith(
      primary: primaryColor,
      onPrimary:
          primaryColor.computeLuminance() > 0.45 ? Colors.black : Colors.white,
      secondary: secondary,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFF171827),
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: scheme.primaryContainer,
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData get dark => darkWithColor(brandColor);

  static ThemeData darkWithColor(Color primaryColor) {
    final secondary = secondaryFor(primaryColor, dark: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryColor,
      onPrimary:
          primaryColor.computeLuminance() > 0.45 ? Colors.black : Colors.white,
      secondary: secondary,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF111318),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF111318),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1D2028),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: scheme.primaryContainer,
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
