import 'package:flutter/material.dart';

/// A small, dependency-free rendering of the Google "G" mark using
/// CustomPainter, so we don't need to ship an image/svg asset just for
/// the "Continue with Google" button.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.42;
    final rect = Rect.fromCircle(radius: radius - strokeWidth / 2, center: center);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Four brand-colored arcs approximating the Google "G".
    const twoPi = 6.28318530718;
    const start = -1.1;

    paint.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(rect, start, twoPi * 0.28, false, paint);

    paint.color = const Color(0xFF34A853); // green
    canvas.drawArc(rect, start + twoPi * 0.28, twoPi * 0.22, false, paint);

    paint.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(rect, start + twoPi * 0.50, twoPi * 0.20, false, paint);

    paint.color = const Color(0xFFEA4335); // red
    canvas.drawArc(rect, start + twoPi * 0.70, twoPi * 0.30, false, paint);

    // Cross-bar of the "G".
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth / 2,
        radius - strokeWidth * 0.35,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) => false;
}