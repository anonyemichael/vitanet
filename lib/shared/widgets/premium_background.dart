import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class PremiumBackground extends StatelessWidget {
  final Widget child;

  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return Stack(
      children: [
        // Base color
        Container(
          color: context.theme.scaffoldBackgroundColor,
        ),
        
        // Very subtle top right glowing blob (Primary Color)
        Positioned(
          top: -200,
          right: -150,
          child: RepaintBoundary(
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isDark 
                        ? context.colorScheme.primary.withValues(alpha: 0.05) 
                        : context.colorScheme.primary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.1, 0.8],
                ),
              ),
            ),
          ),
        ),
        
        // Actual content
        child,
      ],
    );
  }
}
