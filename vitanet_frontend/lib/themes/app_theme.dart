import 'package:flutter/material.dart';

/// Centralized color palette for the VitaNet brand.
/// Kept separate from [AppTheme] so any widget can reach for a brand color
/// without pulling in the full ThemeData (e.g. gradients on the logo mark).
class AppColors {
  AppColors._();

  // Brand
  static const Color brandBlue = Color(0xFF2D7DD2);
  static const Color brandGreen = Color(0xFF16A672);

  // Light mode surfaces
  static const Color lightBackground = Color(0xFFEFF6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F9FB);

  // Dark mode surfaces
  static const Color darkBackground = Color(0xFF0E1620);
  static const Color darkSurface = Color(0xFF16202B);
  static const Color darkSurfaceAlt = Color(0xFF1C2733);

  // Text
  static const Color lightTextPrimary = Color(0xFF11202E);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color darkTextPrimary = Color(0xFFECF2F7);
  static const Color darkTextSecondary = Color(0xFF9AACBC);

  // Utility
  static const Color divider = Color(0xFFE2E9EF);
  static const Color darkDivider = Color(0xFF2A3644);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [brandGreen, brandBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// App-wide theming. Exposes [light] and [dark] ThemeData objects and is
/// consumed via a Riverpod provider (see providers/theme_provider.dart) —
/// this file has zero Riverpod/state dependencies so it stays trivially
/// testable and reusable.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(brightness: Brightness.light);
  static ThemeData get dark => _base(brightness: Brightness.dark);

  static ThemeData _base({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.brandBlue,
            secondary: AppColors.brandGreen,
            surface: AppColors.darkSurface,
            error: Color(0xFFE57373),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: AppColors.darkTextPrimary,
          )
        : const ColorScheme.light(
            primary: AppColors.brandBlue,
            secondary: AppColors.brandGreen,
            surface: AppColors.lightSurface,
            error: Color(0xFFD64545),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: AppColors.lightTextPrimary,
          );

    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      fontFamily: 'Inter',
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
            width: 1,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconTheme: IconThemeData(
        color: isDark ? AppColors.darkTextSecondary : AppColors.brandBlue,
      ),
      colorSchemeSeed: null,
    );
  }
}