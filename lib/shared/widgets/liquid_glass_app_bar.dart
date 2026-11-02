import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// YouTube-style auto-hiding Liquid Glass App Bar for subpages and utility screens.
/// Slides up and disappears smoothly when scrolling down; slides back when scrolling up.
class LiquidGlassAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final double height;
  final bool showBackButton;

  const LiquidGlassAppBar({
    super.key,
    this.title = '',
    this.titleWidget,
    this.leading,
    this.actions,
    this.onBack,
    this.height = 56.0,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveFill = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.90);
    final effectiveBorder = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
        color: effectiveFill,
        border: Border(
          bottom: BorderSide(color: effectiveBorder, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null)
                    leading!
                  else if (showBackButton)
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: titleWidget ??
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: textPrimary,
                          ),
                        ),
                  ),
                  ...?actions,
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
