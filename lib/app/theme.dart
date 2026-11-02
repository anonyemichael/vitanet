import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/constants/app_colors.dart';

/// VitaNet app theme â€” light and dark.
class AppTheme {
  AppTheme._();

  static final String? _jakarta = GoogleFonts.plusJakartaSans().fontFamily;
  static final String? _inter = GoogleFonts.inter().fontFamily;

  // â”€â”€â”€ Light Theme â”€â”€â”€
  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: AppColors.brand,
      primaryContainer: AppColors.brandTint,
      secondary: AppColors.secondaryLight,
      secondaryContainer: AppColors.secondaryContainerLight,
      surface: AppColors.surfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      error: AppColors.errorLight,
      onPrimary: AppColors.onPrimaryLight,
      onSurface: AppColors.onSurfaceLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.pageBg,
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.onSurfaceLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _jakarta,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E9EE), width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.onSurfaceVariantLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.brandTint,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: _inter, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E9EE)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onPrimaryLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontFamily: _inter,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontFamily: _inter,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Dark Theme â”€â”€â”€
  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.mint,
      primaryContainer: Color(0xFF134E4A),
      secondary: AppColors.secondaryDark,
      secondaryContainer: AppColors.secondaryContainerDark,
      surface: AppColors.surfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      error: AppColors.errorDark,
      onPrimary: AppColors.onPrimaryDark,
      onSurface: AppColors.onSurfaceDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.onSurfaceDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _jakarta,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.mint,
        unselectedItemColor: AppColors.onSurfaceVariantDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primaryContainerDark,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: _inter, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.onPrimaryDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontFamily: _inter,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mint,
          side: const BorderSide(color: AppColors.mint, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontFamily: _inter,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Text Theme â”€â”€â”€
  static TextTheme _buildTextTheme(ColorScheme scheme) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: _jakarta,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: _jakarta,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.33,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: _jakarta,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: _inter,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: _jakarta,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: _inter,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: scheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: _inter,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.4,
        color: scheme.onSurfaceVariant,
      ),
      bodyLarge: TextStyle(
        fontFamily: _inter,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: _inter,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: _inter,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: _inter,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        color: scheme.onSurface,
      ),
    );
  }
}
