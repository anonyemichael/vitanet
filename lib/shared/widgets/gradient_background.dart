import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/shared/widgets/premium_background.dart';

/// Reusable gradient background scaffold.
class GradientBackground extends StatelessWidget {
  final Widget child;
  final bool useGradient;

  const GradientBackground({
    super.key,
    required this.child,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!useGradient) return child;

    return PremiumBackground(child: child);
  }
}
