import 'package:flutter/material.dart';

/// VitaNet color tokens for light and dark themes.
class AppColors {
  AppColors._();

  // ── Light Mode ──
  static const Color primaryLight = Color(0xFF06B6D4); // Electric Cyan
  static const Color primaryContainerLight = Color(0xFFCFFAFE);
  static const Color secondaryLight = Color(0xFF8B5CF6); // Deep Violet
  static const Color secondaryContainerLight = Color(0xFFEDE9FE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color errorLight = Color(0xFFEF4444);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color successLight = Color(0xFF10B981);
  static const Color onSurfaceLight = Color(0xFF0F172A);
  static const Color onSurfaceVariantLight = Color(0xFF64748B);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);

  // ── Dark Mode ──
  static const Color primaryDark = Color(0xFF22D3EE); // Cyan 400
  static const Color primaryContainerDark = Color(0xFF164E63); // Cyan 900
  static const Color secondaryDark = Color(0xFFA78BFA); // Violet 400
  static const Color secondaryContainerDark = Color(0xFF4C1D95); // Violet 900
  static const Color surfaceDark = Color(0xFF1E1E1E); // Neutral Dark Gray (Cards)
  static const Color surfaceVariantDark = Color(0xFF2A2A2A); // Lighter Gray
  static const Color backgroundDark = Color(0xFF121212); // Deep Neutral Gray (Background)
  static const Color errorDark = Color(0xFFFCA5A5);
  static const Color warningDark = Color(0xFFFCD34D);
  static const Color successDark = Color(0xFF6EE7B7);
  static const Color onSurfaceDark = Color(0xFFF5F5F5); // White-ish
  static const Color onSurfaceVariantDark = Color(0xFFA3A3A3); // Light Gray
  static const Color onPrimaryDark = Color(0xFF121212);

  // ── Triage Level Colors (shared) ──
  static const Color triageSelfCare = Color(0xFF10B981); // Green
  static const Color triagePharmacist = Color(0xFFFBBF24); // Yellow
  static const Color triageDoctor = Color(0xFFF97316); // Orange
  static const Color triageUrgent = Color(0xFFEF4444); // Red

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkPrimaryGradient = LinearGradient(
    colors: [Color(0xFF2DD4BF), Color(0xFFA5B4FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Pre-computed transparent variants (avoid runtime withValues() calls) ──
  // Dark mode card surfaces
  static const Color darkCardSurface = Color(0xFF1E1E1E);
  static const Color darkCardSurfaceLight = Color(0x0DFFFFFF); // white 5%
  static const Color darkOverlay02 = Color(0x05FFFFFF);        // white 2%
  static const Color darkOverlay10 = Color(0x1AFFFFFF);        // white 10%
  static const Color darkBorder = Color(0x0DFFFFFF);           // white 5%
  
  // Light mode
  static const Color lightShadow04 = Color(0x0A000000);       // black 4%
  static const Color lightShadow05 = Color(0x0D000000);       // black 5%
  static const Color lightShadow08 = Color(0x14000000);       // black 8%
  static const Color lightBorder = Color(0x0D000000);          // black 5%

  // Primary with alpha (for selected states)
  static const Color primaryLight12 = Color(0x1F06B6D4);      // primary 12%
  static const Color primaryDark12 = Color(0x1F22D3EE);       // primary 12%
}
