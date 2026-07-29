import 'package:flutter/material.dart';
import 'package:vitanet_frontend/themes/app_theme.dart';


/// The heart-pulse mark + wordmark used on the splash/onboarding screens.
class VitaNetLogo extends StatelessWidget {
  final double size;
  const VitaNetLogo({super.key, this.size = 92});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: size,
          width: size,
          child: CustomPaint(painter: _HeartPulsePainter()),
        ),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              fontFamily: theme.textTheme.headlineLarge?.fontFamily,
            ),
            children: const [
              TextSpan(
                text: 'Vita',
                style: TextStyle(color: AppColors.brandBlue),
              ),
              TextSpan(
                text: 'Net',
                style: TextStyle(color: AppColors.brandGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your Health, Connected',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _HeartPulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final heartPath = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..cubicTo(w * 0.05, h * 0.55, w * 0.05, h * 0.15, w * 0.5, h * 0.32)
      ..cubicTo(w * 0.95, h * 0.15, w * 0.95, h * 0.55, w * 0.5, h * 0.88)
      ..close();

    final gradientPaint = Paint()
      ..shader = AppColors.heroGradient.createShader(
        Rect.fromLTWH(0, 0, w, h),
      );
    canvas.drawPath(heartPath, gradientPaint);

    // Pulse line across the heart's center.
    final pulsePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pulse = Path()
      ..moveTo(w * 0.16, h * 0.5)
      ..lineTo(w * 0.34, h * 0.5)
      ..lineTo(w * 0.42, h * 0.32)
      ..lineTo(w * 0.55, h * 0.66)
      ..lineTo(w * 0.63, h * 0.5)
      ..lineTo(w * 0.84, h * 0.5);
    canvas.drawPath(pulse, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _HeartPulsePainter oldDelegate) => false;
}