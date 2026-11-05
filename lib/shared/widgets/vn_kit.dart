import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/constants/app_colors.dart';

/// VitaNet redesign UI kit.
///
/// Small, theme-aware building blocks shared by the patient screens so the
/// light design spec (white cards on #F8FAFC, 1px #E2E9EE borders, teal brand)
/// has a consistent dark-mode equivalent.

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Palette
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class VnPalette {
  final bool isDark;
  const VnPalette._(this.isDark);

  static VnPalette of(BuildContext context) =>
      VnPalette._(Theme.of(context).brightness == Brightness.dark);

  Color get page => isDark ? AppColors.backgroundDark : AppColors.pageBg;
  Color get surface => isDark ? AppColors.surfaceDark : Colors.white;
  Color get surfaceAlt =>
      isDark ? AppColors.surfaceVariantDark : const Color(0xFFF1F5F9);
  Color get surfaceSoft =>
      isDark ? const Color(0xFF181818) : AppColors.pageBg;
  Color get ink => isDark ? AppColors.onSurfaceDark : AppColors.ink;
  Color get inkSoft => isDark ? const Color(0xFFD4D4D4) : AppColors.inkSoft;
  Color get muted => isDark ? AppColors.onSurfaceVariantDark : AppColors.inkMuted;
  Color get faint => isDark ? const Color(0xFF737373) : const Color(0xFF94A3B8);
  Color get line => isDark ? const Color(0xFF2E2E2E) : AppColors.line;
  Color get divider => isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9);
  Color get brand => isDark ? AppColors.mint : AppColors.brand;
  Color get brandDeep => isDark ? AppColors.mintLight : AppColors.brandDark;
  Color get onBrand => isDark ? const Color(0xFF03201C) : Colors.white;
  Color get brandTint => isDark ? const Color(0xFF134E4A) : AppColors.brandTint;
  Color get brandWash => isDark ? const Color(0xFF0F2A27) : AppColors.brandWash;
  Color get brandBorder => isDark ? const Color(0xFF1F5F58) : const Color(0xFF99F6E4);
  Color get danger => isDark ? const Color(0xFFF87171) : AppColors.danger;
  Color get dangerTint => isDark ? const Color(0xFF3B1414) : AppColors.dangerTint;
  Color get switchOff => isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1);
  Color get scrim => const Color(0x8C0F172A);

  /// Tinted icon-chip background: the spec colour in light mode, a translucent
  /// wash of the foreground in dark mode.
  Color tintBg(Color lightBg, Color fg) =>
      isDark ? fg.withValues(alpha: 0.18) : lightBg;

  /// Foreground for a tinted chip: lifts dark spec colours for dark mode.
  Color tintFg(Color fg) =>
      isDark ? Color.lerp(fg, Colors.white, 0.35)! : fg;
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Typography
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class VnText {
  VnText._();

  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Structure
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Top bar used by pushed screens: 44px back button + 22px/800 title.
class VnTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool showBack;
  final Widget? subtitle;

  const VnTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
    this.showBack = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (showBack) ...[
            VnIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Back',
              iconSize: 26,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VnText.heading(22, color: p.ink),
                ),
                ?subtitle,
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Square, borderless (or bordered) 44px icon button with tooltip/semantics.
class VnIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final double radius;
  final Color? background;
  final Color? foreground;
  final bool bordered;
  final Widget? badge;

  const VnIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.radius = 14,
    this.background,
    this.foreground,
    this.bordered = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: background ?? (bordered ? p.surface : Colors.transparent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: bordered ? BorderSide(color: p.line) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: iconSize, color: foreground ?? p.ink),
                  ?badge,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White card with 1px line border and 20px radius.
class VnCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const VnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final content = Padding(padding: padding, child: child);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Material(
        color: color ?? p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor ?? p.line, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Uppercase 12px section label ("APPEARANCE").
class VnSectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;
  const VnSectionLabel(this.text,
      {super.key, this.padding = const EdgeInsets.only(left: 4)});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: VnText.body(12,
              weight: FontWeight.w700, color: p.muted, letterSpacing: 0.6),
        ),
      ),
    );
  }
}

/// 18px section heading with optional trailing link ("See all").
class VnSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  const VnSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                style: VnText.heading(18, weight: FontWeight.w700, color: p.ink)),
          ),
        ),
        ?trailing,
        if (action != null)
          VnLink(label: action!, onTap: onAction),
      ],
    );
  }
}

/// Inline teal text link with a 44px tall hit area.
class VnLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final FontWeight weight;
  final Color? color;

  const VnLink({
    super.key,
    required this.label,
    this.onTap,
    this.fontSize = 14,
    this.weight = FontWeight.w600,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            widthFactor: 1,
            child: Text(label,
                style: VnText.body(fontSize, weight: weight, color: color ?? p.brand)),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square tinted icon tile.
class VnIconTile extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double radius;
  final double iconSize;

  const VnIconTile({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 38,
    this.radius = 12,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.tintBg(bg, fg),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: p.tintFg(fg)),
    );
  }
}

/// White grouped list (settings style) with 1px dividers.
class VnListGroup extends StatelessWidget {
  final List<Widget> children;
  final double radius;
  const VnListGroup({super.key, required this.children, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Divider(height: 1, thickness: 1, color: p.divider));
      }
    }
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

/// A list row: optional leading tile, title/subtitle, trailing value + chevron.
class VnListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool chevron;
  final EdgeInsetsGeometry padding;

  const VnListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.chevron = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: VnText.body(15,
                            weight: FontWeight.w600, color: titleColor ?? p.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: VnText.body(12, color: p.muted)),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(value!, style: VnText.body(14, color: p.muted)),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron && onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 22, color: p.faint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-style switch from the spec (50x30 track, 24px knob).
class VnSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  const VnSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 54,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? p.brand : p.switchOff,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x400F172A),
                          blurRadius: 3,
                          offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled primary button (teal by default).
class VnButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconAfter;
  final double height;
  final double radius;
  final Color? background;
  final Color? foreground;
  final double fontSize;
  final bool loading;
  final bool expand;
  final List<BoxShadow>? shadow;

  const VnButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconAfter = false,
    this.height = 56,
    this.radius = 16,
    this.background,
    this.foreground,
    this.fontSize = 16,
    this.loading = false,
    this.expand = true,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final bg = background ?? p.brand;
    final fg = foreground ?? p.onBrand;
    final iconW = icon == null ? null : Icon(icon, size: 20, color: fg);
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconW != null && !iconAfter) ...[iconW, const SizedBox(width: 10)],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: VnText.body(fontSize, weight: FontWeight.w700, color: fg)),
              ),
              if (iconW != null && iconAfter) ...[const SizedBox(width: 10), iconW],
            ],
          );
    final btn = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: Material(
        color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(child: child),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

/// Outlined / soft secondary button.
class VnOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double radius;
  final Color? borderColor;
  final Color? foreground;
  final Color? background;
  final double fontSize;
  final bool expand;
  final Widget? leading;

  const VnOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.height = 52,
    this.radius = 16,
    this.borderColor,
    this.foreground,
    this.background,
    this.fontSize = 15,
    this.expand = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final fg = foreground ?? p.ink;
    final btn = Material(
      color: background ?? Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: borderColor == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: borderColor ?? p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.body(fontSize, weight: FontWeight.w600, color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

/// Segmented control: #F1F5F9 track with white selected pill.
class VnSegmented extends StatelessWidget {
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  const VnSegmented({
    super.key,
    required this.options,
    required this.index,
    required this.onChanged,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? p.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: i == index && !p.isDark
                          ? const [
                              BoxShadow(
                                  color: Color(0x1A0F172A),
                                  blurRadius: 3,
                                  offset: Offset(0, 1)),
                            ]
                          : null,
                    ),
                    child: Text(
                      options[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.body(14,
                          weight: i == index ? FontWeight.w700 : FontWeight.w600,
                          color: i == index ? p.ink : p.muted),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill chip (selectable).
class VnChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final double fontSize;

  const VnChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.height = 40,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final fg = selected ? p.onBrand : p.inkSoft;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.brand : p.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? p.brand : p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: VnText.body(fontSize, weight: FontWeight.w600, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet container with grab handle (28px top radius).
class VnSheet extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  const VnSheet({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 28),
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final items = <Widget>[
      Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: p.isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    ];
    for (final c in children) {
      items
        ..add(SizedBox(height: gap))
        ..add(c);
    }
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items,
          ),
        ),
      ),
    );
  }
}

/// Shows a [VnSheet]-style modal bottom sheet.
Future<T?> showVnSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C0F172A),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: builder(ctx),
    ),
  );
}

/// Dialog container (28px radius, 24px padding).
class VnDialog extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const VnDialog({super.key, required this.children, this.gap = 14});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(height: gap));
      items.add(children[i]);
    }
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items,
        ),
      ),
    );
  }
}

/// Circular initials avatar.
class VnAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? bg;
  final Color? fg;
  final ImageProvider? image;
  final double fontSize;
  final Color? borderColor;
  final double borderWidth;

  const VnAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.bg,
    this.fg,
    this.image,
    this.fontSize = 17,
    this.borderColor,
    this.borderWidth = 0,
  });

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final background = bg ?? p.brandTint;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.isDark && bg != null ? bg!.withValues(alpha: 0.25) : background,
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? p.surface, width: borderWidth)
            : null,
        image: image == null
            ? null
            : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image != null
          ? null
          : Text(
              initials(name),
              style: VnText.heading(fontSize,
                  color: p.isDark ? p.tintFg(fg ?? AppColors.brandDark) : (fg ?? AppColors.brandDark)),
            ),
    );
  }
}

/// Simple text field styled to spec (52px, 14px radius, line border).
class VnTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? initialValue;

  const VnTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    final field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: VnText.body(15, color: p.ink, weight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: VnText.body(15, color: p.faint),
        filled: true,
        fillColor: p.surface,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: p.muted),
        suffixIcon: suffix,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 14 : 15),
        border: b(p.line),
        enabledBorder: b(p.line),
        focusedBorder: b(p.brand, 2),
        errorBorder: b(p.danger),
        focusedErrorBorder: b(p.danger, 2),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}

/// Straight-edged progress bar.
class VnProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? track;
  final double height;
  const VnProgressBar({
    super.key,
    required this.value,
    this.color,
    this.track,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track ?? p.surfaceAlt)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color ?? p.brand,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Enterprise Responsive Scroll Physics
// ─────────────────────────────────────────────────────────────────────────────

/// High-responsiveness clamping scroll physics.
///
/// 1. Clamps strictly to viewport bounds (eliminating infinite white overscroll).
/// 2. Reduces [dragStartDistanceMotionThreshold] to 3.5 logical pixels (down
///    from the default 18.0px dead zone), initiating list tracking immediately
///    when the finger touches and moves.
/// 3. Retains native Android ballistic fling simulations.
class VnScrollPhysics extends ClampingScrollPhysics {
  const VnScrollPhysics({super.parent});

  @override
  VnScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return VnScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

/// Always-scrollable variant that maintains immediate 3.5px drag response,
/// hard boundary clamping, and support for pull-to-refresh even when content
/// fits within the viewport.
class VnAlwaysScrollablePhysics extends AlwaysScrollableScrollPhysics {
  const VnAlwaysScrollablePhysics({super.parent = const VnScrollPhysics()});

  @override
  VnAlwaysScrollablePhysics applyTo(ScrollPhysics? ancestor) {
    return VnAlwaysScrollablePhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}


/// Canonical responsive clamping physics instance.
const vnClampingPhysics = VnAlwaysScrollablePhysics();
