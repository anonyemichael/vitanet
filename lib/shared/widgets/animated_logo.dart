import 'package:flutter/material.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';

/// App logo with optional wordmark. Uses the vector [VitaNetLogo].
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
        VitaNetLogo(size: size),
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
