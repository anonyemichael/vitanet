import 'package:flutter/material.dart';

/// VitaNet brand mark: a rounded teal square with a mint pulse line.
///
/// Drawn in code so it stays crisp at any size and has no baked-in
/// background corners (the PNG assets have white corners).
class VitaNetLogo extends StatelessWidget {
  final double size;

  /// 0..1 — how much of the pulse line is drawn. Animate it for a trace effect.
  final double pulseProgress;
  final bool glow;

  const VitaNetLogo({
    super.key,
    this.size = 64,
    this.pulseProgress = 1,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'VitaNet logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: glow
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
                    blurRadius: size * 0.4,
                    offset: Offset(0, size * 0.1),
                  ),
                ],
              )
            : null,
        child: CustomPaint(
          size: Size.square(size),
          painter: _VitaNetLogoPainter(pulseProgress),
        ),
      ),
    );
  }
}

class _VitaNetLogoPainter extends CustomPainter {
  final double progress;

  _VitaNetLogoPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(18 * s));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14897E), Color(0xFF053F38)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.1, -0.1),
          radius: 0.5,
          colors: [
            const Color(0xFF2DD4BF).withValues(alpha: 0.45),
            const Color(0xFF2DD4BF).withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    final path = Path()
      ..moveTo(10 * s, 32 * s)
      ..lineTo(20 * s, 32 * s)
      ..lineTo(24.5 * s, 22 * s)
      ..lineTo(32.5 * s, 42 * s)
      ..lineTo(36.5 * s, 32 * s)
      ..lineTo(54 * s, 32 * s);

    final drawn = progress >= 1
        ? path
        : _extract(path, progress.clamp(0.0, 1.0));

    canvas.drawPath(
      drawn,
      Paint()
        ..color = const Color(0xFF5EEAD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _extract(Path path, double t) {
    final out = Path();
    for (final metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(_VitaNetLogoPainter old) => old.progress != progress;
}
