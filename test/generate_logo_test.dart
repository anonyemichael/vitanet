import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate Logo PNG', () async {
    const size = Size(1024, 1024);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Scale from 32x32 viewBox to 1024x1024
    final scale = size.width / 32.0;
    canvas.scale(scale, scale);

    final bgRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 32, 32),
      const Radius.circular(8.0),
    );

    // Drop shadow
    canvas.drawRRect(
      bgRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Gradient Background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F766E), Color(0xFF06403C)],
      ).createShader(const Rect.fromLTWH(0, 0, 32, 32))
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(bgRect, bgPaint);

    // Heartbeat Path
    final path = Path();
    path.moveTo(5, 16);
    path.lineTo(10, 16);
    path.lineTo(12, 11);
    path.lineTo(16, 21);
    path.lineTo(18, 16);
    path.lineTo(27, 16);

    final pathPaint = Paint()
      ..color = const Color(0xFF5EEAD4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF5EEAD4).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, pathPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final file = File('assets/logo.png');
    await file.writeAsBytes(buffer);
  });
}
