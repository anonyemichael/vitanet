import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class AnimatedChatBackground extends StatefulWidget {
  const AnimatedChatBackground({super.key});

  @override
  State<AnimatedChatBackground> createState() => _AnimatedChatBackgroundState();
}

class _AnimatedChatBackgroundState extends State<AnimatedChatBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MeshGradientPainter(
            progress: _controller.value,
            isDark: isDark,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),
        );
      },
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _MeshGradientPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Color definitions
    final color1 = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    final color2 = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
    final color3 = isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF);

    final w = size.width;
    final h = size.height;

    // Node 1
    final x1 = w * (0.5 + 0.3 * math.cos(progress * 2 * math.pi));
    final y1 = h * (0.3 + 0.2 * math.sin(progress * 2 * math.pi));
    paint.color = color1.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(x1, y1), w * 0.6, paint);

    // Node 2
    final x2 = w * (0.5 + 0.4 * math.sin(progress * 2 * math.pi + math.pi / 2));
    final y2 = h * (0.7 + 0.2 * math.cos(progress * 2 * math.pi));
    paint.color = color2.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(x2, y2), w * 0.5, paint);

    // Node 3
    final x3 = w * (0.2 + 0.3 * math.cos(progress * 2 * math.pi + math.pi));
    final y3 = h * (0.5 + 0.3 * math.sin(progress * 2 * math.pi + math.pi));
    paint.color = color3.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(x3, y3), w * 0.55, paint);
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
