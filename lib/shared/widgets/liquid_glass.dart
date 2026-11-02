import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable Liquid Glass Container with specular highlight, 
/// backdrop blur, and guaranteed ClipRRect isolation to prevent bleed.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? fillColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final Clip clipBehavior;

  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.borderRadius = 20.0,
    this.padding,
    this.margin,
    this.fillColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.shadows,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final effectiveFill = fillColor ??
        (isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.60)
            : const Color(0xFFFFFFFF).withValues(alpha: 0.68));

    final effectiveBorder = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.85));

    final defaultShadows = shadows ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ];

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: defaultShadows,
      ),
      // IMPORTANT: Always wrap BackdropFilter inside ClipRRect to prevent blur bleed
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveFill,
              borderRadius: radius,
              border: Border.all(
                color: effectiveBorder,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// GPU-optimized Liquid Glass Surface with static hoisted blur,
/// refractive diagonal gradient, specular top-left rim border, and soft outer refraction shadow.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderWidth;
  final bool enableShadow;
  final Gradient? customGradient;
  final Gradient? customRimGradient;
  final double? width;
  final double? height;

  /// Hoisted static blur filter to guarantee zero memory reallocations during high-FPS scroll cycles
  static final ImageFilter staticBlurFilter = ImageFilter.blur(sigmaX: 8, sigmaY: 8);

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.padding,
    this.margin,
    this.onTap,
    this.borderWidth = 1.2,
    this.enableShadow = true,
    this.customGradient,
    this.customRimGradient,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rimGradient = customRimGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color.fromRGBO(255, 255, 255, 0.35),
                  Color.fromRGBO(13, 148, 136, 0.20),
                ]
              : const [
                  Color.fromRGBO(255, 255, 255, 0.90),
                  Color.fromRGBO(13, 148, 136, 0.20),
                ],
        );

    final fillGradient = customGradient ??
        (isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(30, 41, 59, 0.75),
                  Color.fromRGBO(15, 23, 42, 0.45),
                  Color.fromRGBO(13, 148, 136, 0.15),
                ],
                stops: [0.0, 0.5, 1.0],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(255, 255, 255, 0.72),
                  Color.fromRGBO(255, 255, 255, 0.24),
                  Color.fromRGBO(240, 253, 250, 0.45),
                ],
                stops: [0.0, 0.5, 1.0],
              ));

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: fillGradient,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: rimGradient,
        boxShadow: enableShadow
            ? [
                BoxShadow(
                  color: isDark
                      ? const Color(0x55000000)
                      : const Color.fromRGBO(15, 23, 42, 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: staticBlurFilter,
          child: content,
        ),
      ),
    );
  }
}

/// Compact floating frosted glass badge for image corners & metadata tags.
class LiquidGlassBadge extends StatelessWidget {
  final Widget child;
  final Color? tint;
  final Color? borderTint;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const LiquidGlassBadge({
    super.key,
    required this.child,
    this.tint,
    this.borderTint,
    this.blur = 12.0,
    this.borderRadius = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final effectiveFill = tint ??
        (isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.70)
            : Colors.white.withValues(alpha: 0.75));

    final effectiveBorder = borderTint ??
        (isDark
            ? Colors.white.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.80));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveFill,
            borderRadius: radius,
            border: Border.all(
              color: effectiveBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ambient mesh canvas that provides chromatic depth for liquid glass elements to refract.
/// Blends Medical Teal (#0D9488) and Crimson (#E11D48) over clean slate backdrop.
class AmbientCanvas extends StatelessWidget {
  final Widget child;

  const AmbientCanvas({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF4F7FB);

    return Container(
      color: baseColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Radial Gradient 1: Medical Teal Aura at Top-Left
          Positioned(
            top: -120,
            left: -100,
            width: 650,
            height: 650,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0D9488).withValues(alpha: isDark ? 0.12 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Radial Gradient 2: Crimson Emergency Glow at Top-Right
          Positioned(
            top: 40,
            right: -140,
            width: 580,
            height: 580,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE11D48).withValues(alpha: isDark ? 0.09 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Radial Gradient 3: Soft Indigo depth anchor at Bottom-Center
          Positioned(
            bottom: -150,
            left: 200,
            width: 700,
            height: 700,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.08 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Foreground Content
          child,
        ],
      ),
    );
  }
}
