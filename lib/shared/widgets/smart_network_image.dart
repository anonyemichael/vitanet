import 'package:flutter/material.dart';

/// Production-grade resilient image component with:
/// - Instant rendering for network URLs and local assets
/// - Smooth subtle loading indicator
/// - High-fidelity clinical icon fallback with zero "offline" badge spam
/// - Safe finite cache dimension calculations
/// - Optional bottom gradient scrim
class SmartNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showBottomScrim;
  final double scale;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final String? semanticLabel;

  const SmartNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showBottomScrim = false,
    this.scale = 1.0,
    this.fallbackIcon = Icons.medical_services_rounded,
    this.fallbackColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final trimmedUrl = imageUrl.trim();

    if (trimmedUrl.isEmpty) {
      return _buildFallback(context);
    }

    final isAsset = trimmedUrl.startsWith('assets/');

    // Only compute cache dimensions for finite, valid bounds
    final int? resolvedCacheWidth = width != null && width!.isFinite && width! > 0
        ? (width! * 2.0).clamp(120, 1200).toInt()
        : null;
    final int? resolvedCacheHeight = height != null && height!.isFinite && height! > 0
        ? (height! * 2.0).clamp(120, 1200).toInt()
        : null;

    final imageWidth = (width != null && width!.isFinite) ? width : null;
    final imageHeight = (height != null && height!.isFinite) ? height : null;

    Widget imageWidget = isAsset
        ? Image.asset(
            trimmedUrl,
            width: imageWidth,
            height: imageHeight,
            fit: fit,
            cacheWidth: resolvedCacheWidth,
            cacheHeight: resolvedCacheHeight,
            gaplessPlayback: true,
            semanticLabel: semanticLabel,
            errorBuilder: (context, error, stackTrace) => _buildFallback(context),
          )
        : Image.network(
            trimmedUrl,
            width: imageWidth,
            height: imageHeight,
            fit: fit,
            cacheWidth: resolvedCacheWidth,
            cacheHeight: resolvedCacheHeight,
            gaplessPlayback: true,
            semanticLabel: semanticLabel,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: imageWidth,
                height: imageHeight,
                color: const Color(0xFF1E293B),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fallbackColor ?? const Color(0xFF0D9488),
                      ),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildFallback(context),
          );

    // Apply smooth zoom scale if specified
    if (scale != 1.0) {
      imageWidget = AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: imageWidget,
      );
    }

    // Stack with bottom gradient scrim if enabled
    if (showBottomScrim) {
      imageWidget = Stack(
        fit: StackFit.passthrough,
        children: [
          imageWidget,
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.4, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (radius != BorderRadius.zero) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: height,
          child: imageWidget,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: imageWidget,
    );
  }

  Widget _buildFallback(BuildContext context) {
    final accent = fallbackColor ?? const Color(0xFF0D9488);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: borderRadius,
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: (height != null && height! < 100) ? 28 : 36,
          color: accent,
        ),
      ),
    );
  }
}
