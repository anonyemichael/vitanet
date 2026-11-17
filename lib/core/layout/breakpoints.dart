import 'package:flutter/widgets.dart';

/// One set of screen-size steps for the whole app (UI/UX audit UX-05), following Material 3:
///   compact  < 600   phones
///   medium   600-839 large phones, small tablets, split screen
///   expanded >= 840  tablets in landscape, desktop: side navigation, two-pane layouts
///   large    >= 1200 wide desktop: extra side panels
/// Use these instead of writing a width number on a screen, so every area switches layout at the same width.
class VnBreakpoints {
  VnBreakpoints._();

  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;

  static double _w(BuildContext c) => MediaQuery.sizeOf(c).width;

  static bool isMedium(BuildContext c) => _w(c) >= medium;
  static bool isExpanded(BuildContext c) => _w(c) >= expanded;
  static bool isLarge(BuildContext c) => _w(c) >= large;
}
