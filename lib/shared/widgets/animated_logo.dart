import 'package:flutter/material.dart';

/// Exact replica of the landing page logo without modifications, edits, or animations.
class AnimatedLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AnimatedLogo({
    super.key,
    this.size = 80,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _LogoPainter(),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          Text(
            'VitaNet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The original SVG viewBox is 32x32, so we scale it.
    final scale = size.width / 32.0;
    canvas.scale(scale, scale);

    // 1. Background Rounded Rectangle
    // <rect width="32" height="32" rx="7" fill="#0A5C56" /> (Using primary dark green instead of currentColor)
    final bgPaint = Paint()
      ..color = const Color(0xFF0A5C56) 
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 32, 32),
        const Radius.circular(7.0),
      ),
      bgPaint,
    );

    // 2. Heartbeat Path
    // <path d="M6 16h4l2-5 4 10 2-5h8" fill="none" stroke="#5EEAD4" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" />
    final pathPaint = Paint()
      ..color = const Color(0xFF5EEAD4) // The exact stroke color from the landing page SVG
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(6, 16);
    path.relativeLineTo(4, 0); // h4
    path.relativeLineTo(2, -5); // l2-5
    path.relativeLineTo(4, 10); // 4 10 (relative)
    path.relativeLineTo(2, -5); // 2 -5 (relative)
    path.relativeLineTo(8, 0); // h8

    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
