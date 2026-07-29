import 'package:flutter/material.dart';

/// Lightweight responsive helpers — no external package required.
/// Breakpoints follow common Flutter/Material conventions:
///  < 600  : mobile
///  600-1024 : tablet
///  > 1024 : desktop/web
enum DeviceType { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  DeviceType get deviceType {
    final width = screenWidth;
    if (width >= 1024) return DeviceType.desktop;
    if (width >= 600) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// Scales a base (mobile) font size gently up for larger surfaces.
  double responsiveFont(double base) {
    switch (deviceType) {
      case DeviceType.mobile:
        return base;
      case DeviceType.tablet:
        return base * 1.08;
      case DeviceType.desktop:
        return base * 1.15;
    }
  }

  /// Content max width so wide screens don't stretch cards edge-to-edge.
  double get maxContentWidth {
    switch (deviceType) {
      case DeviceType.mobile:
        return double.infinity;
      case DeviceType.tablet:
        return 560;
      case DeviceType.desktop:
        return 480;
    }
  }

  /// Horizontal page padding that grows slightly with screen size.
  double get horizontalPadding {
    switch (deviceType) {
      case DeviceType.mobile:
        return 24;
      case DeviceType.tablet:
        return 40;
      case DeviceType.desktop:
        return 0; // centering + maxContentWidth handles it
    }
  }
}