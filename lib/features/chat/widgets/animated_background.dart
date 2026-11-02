import 'dart:math' as math;
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

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _MeshGradientPainter(
              progress: _controller.value,
              isDark: isDark,
            ),
            child: Container(),
          );
        },
      ),
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _MeshGradientPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Color definitions
    final color1 = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    final color2 = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
    final color3 = isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF);

    final w = size.width;
    final h = size.height;

    // Node 1
    final c1 = Offset(
      w * (0.5 + 0.3 * math.cos(progress * 2 * math.pi)),
      h * (0.3 + 0.2 * math.sin(progress * 2 * math.pi)),
    );
    final r1 = w * 0.6;
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [color1.withValues(alpha: 0.35), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));
    canvas.drawCircle(c1, r1, p1);

    // Node 2
    final c2 = Offset(
      w * (0.5 + 0.4 * math.sin(progress * 2 * math.pi + math.pi / 2)),
      h * (0.7 + 0.2 * math.cos(progress * 2 * math.pi)),
    );
    final r2 = w * 0.5;
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [color2.withValues(alpha: 0.3), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));
    canvas.drawCircle(c2, r2, p2);

    // Node 3
    final c3 = Offset(
      w * (0.2 + 0.3 * math.cos(progress * 2 * math.pi + math.pi)),
      h * (0.5 + 0.3 * math.sin(progress * 2 * math.pi + math.pi)),
    );
    final r3 = w * 0.55;
    final p3 = Paint()
      ..shader = RadialGradient(
        colors: [color3.withValues(alpha: 0.3), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c3, radius: r3));
    canvas.drawCircle(c3, r3, p3);
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
