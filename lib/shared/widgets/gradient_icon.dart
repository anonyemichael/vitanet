import 'package:flutter/material.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final List<Color>? colors;

  const GradientIcon({
    super.key,
    required this.icon,
    required this.size,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = colors ?? [
      context.colorScheme.primary,
      context.colorScheme.tertiary,
    ];

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Icon(
        icon,
        size: size,
        color: Colors.white, // Color is ignored due to srcIn blend mode
      ),
    );
  }
}
