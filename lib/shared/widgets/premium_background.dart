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
          color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
        ),
        
        // Top right glowing blob (Primary Blue)
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark 
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.25) 
                  : const Color(0xFF3B82F6).withValues(alpha: 0.12),
            ),
          ),
        ),
        
        // Bottom left glowing blob (Emerald Green)
        Positioned(
          bottom: -100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark 
                  ? const Color(0xFF10B981).withValues(alpha: 0.15) 
                  : const Color(0xFF10B981).withValues(alpha: 0.1),
            ),
          ),
        ),
        
        // Center right subtle blob (Purple)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          right: -150,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark 
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.15) 
                  : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            ),
          ),
        ),
        
        // Glassmorphism massive blur to create the mesh effect
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        
        // Actual content
        child,
      ],
    );
  }
}
