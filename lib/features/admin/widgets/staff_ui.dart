import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vitanet/core/constants/app_colors.dart';

/// Shared visual language for the clinical staff / hospital portal.
///
/// Light values follow the approved mockups exactly; dark values keep the
/// same hierarchy for night shifts.

// ─── Palette ───

class StaffPalette {
  final bool dark;
  final Color bg;
  final Color card;
  final Color ink;
  final Color body;
  final Color inkSoft;
  final Color muted;
  final Color faint;
  final Color line;
  final Color divider;
  final Color fill;
  final Color track;
  final Color chip;
  final Color primaryBtn;
  final Color accent;
  final Color handle;
  final Color shadow;

  const StaffPalette._({
    required this.dark,
    required this.bg,
    required this.card,
    required this.ink,
    required this.body,
    required this.inkSoft,
    required this.muted,
    required this.faint,
    required this.line,
    required this.divider,
    required this.fill,
    required this.track,
    required this.chip,
    required this.primaryBtn,
    required this.accent,
    required this.handle,
    required this.shadow,
  });

  static const StaffPalette light = StaffPalette._(
    dark: false,
    bg: AppColors.staffBg,
    card: Color(0xFFFFFFFF),
    ink: AppColors.ink,
    body: Color(0xFF334155),
    inkSoft: AppColors.inkSoft,
    muted: AppColors.inkMuted,
    faint: Color(0xFF94A3B8),
    line: AppColors.line,
    divider: Color(0xFFF1F5F9),
    fill: Color(0xFFF8FAFC),
    track: Color(0xFFE2E8F0),
    chip: Color(0xFFF1F5F9),
    primaryBtn: AppColors.staffNavy,
    accent: AppColors.brand,
    handle: Color(0xFFCBD5E1),
    shadow: Color(0x0F0F172A),
  );

  static const StaffPalette night = StaffPalette._(
    dark: true,
    bg: Color(0xFF070C16),
    card: Color(0xFF111A2B),
    ink: Color(0xFFF1F5F9),
    body: Color(0xFFCBD5E1),
    inkSoft: Color(0xFFCBD5E1),
    muted: Color(0xFF94A3B8),
    faint: Color(0xFF64748B),
    line: Color(0xFF243247),
    divider: Color(0xFF1C2638),
    fill: Color(0xFF172236),
    track: Color(0xFF1C2638),
    chip: Color(0xFF1C2638),
    primaryBtn: AppColors.brand,
    accent: AppColors.mintLight,
    handle: Color(0xFF334155),
    shadow: Color(0x00000000),
  );

  static StaffPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? night : light;

  ToneColors tone(StaffTone t) => dark ? t._dark : t._light;
}

class ToneColors {
  /// Soft tag / tile background.
  final Color bg;

  /// Text on [bg].
  final Color fg;

  /// Solid colour for dots, bars and strong text.
  final Color strong;

  const ToneColors(this.bg, this.fg, this.strong);
}

enum StaffTone {
  danger(
    ToneColors(Color(0xFFFEE2E2), Color(0xFF991B1B), Color(0xFFDC2626)),
    ToneColors(Color(0x33DC2626), Color(0xFFFCA5A5), Color(0xFFF87171)),
  ),
  amber(
    ToneColors(Color(0xFFFEF3C7), Color(0xFF92400E), Color(0xFFF59E0B)),
    ToneColors(Color(0x33F59E0B), Color(0xFFFCD34D), Color(0xFFFBBF24)),
  ),
  green(
    ToneColors(Color(0xFFD1FAE5), Color(0xFF065F46), Color(0xFF10B981)),
    ToneColors(Color(0x3310B981), Color(0xFF6EE7B7), Color(0xFF34D399)),
  ),
  brand(
    ToneColors(Color(0xFFCCFBF1), Color(0xFF115E59), Color(0xFF0F766E)),
    ToneColors(Color(0x332DD4BF), Color(0xFF5EEAD4), Color(0xFF2DD4BF)),
  ),
  indigo(
    ToneColors(Color(0xFFE0E7FF), Color(0xFF3730A3), Color(0xFF6366F1)),
    ToneColors(Color(0x336366F1), Color(0xFFC7D2FE), Color(0xFF818CF8)),
  ),
  pink(
    ToneColors(Color(0xFFFCE7F3), Color(0xFF9D174D), Color(0xFFEC4899)),
    ToneColors(Color(0x33EC4899), Color(0xFFF9A8D4), Color(0xFFF472B6)),
  ),
  sky(
    ToneColors(Color(0xFFE0F2FE), Color(0xFF075985), Color(0xFF0EA5E9)),
    ToneColors(Color(0x330EA5E9), Color(0xFF7DD3FC), Color(0xFF38BDF8)),
  ),
  violet(
    ToneColors(Color(0xFFEDE9FE), Color(0xFF6D28D9), Color(0xFF7C3AED)),
    ToneColors(Color(0x337C3AED), Color(0xFFC4B5FD), Color(0xFFA78BFA)),
  ),
  orange(
    ToneColors(Color(0xFFFFEDD5), Color(0xFF9A3412), Color(0xFFF97316)),
    ToneColors(Color(0x33F97316), Color(0xFFFDBA74), Color(0xFFFB923C)),
  ),
  neutral(
    ToneColors(Color(0xFFF1F5F9), Color(0xFF334155), Color(0xFF94A3B8)),
    ToneColors(Color(0xFF1C2638), Color(0xFFCBD5E1), Color(0xFF64748B)),
  );

  final ToneColors _light;
  final ToneColors _dark;
  const StaffTone(this._light, this._dark);
}

/// Staff-portal danger red used for destructive text and critical numbers.
const Color kStaffDanger = AppColors.danger; // #B91C1C
const Color kStaffGreen = Color(0xFF047857);
const Color kStaffAmber = Color(0xFFB45309);

// ─── Type ───

TextStyle staffHeading(
  double size, {
  FontWeight weight = FontWeight.w800,
  Color? color,
  double? height,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

TextStyle staffBody(
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

// ─── Layout ───

/// Centres page content and caps its width so tablet / web layouts stay
/// readable.
class StaffContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const StaffContent({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// White rounded card.
class StaffCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Border? border;
  final bool shadow;

  const StaffCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.color,
    this.border,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadow
            ? [BoxShadow(color: p.shadow, blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: child,
    );
  }
}

/// Tappable surface with ink ripple clipped to the given radius.
class StaffTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;
  final String? semanticLabel;

  const StaffTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.radius = 16,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final w = Material(
      color: color ?? Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
    );
    if (semanticLabel == null) return w;
    return Semantics(button: true, label: semanticLabel, child: w);
  }
}

// ─── Small pieces ───

class StaffTag extends StatelessWidget {
  final String text;
  final StaffTone tone;
  final double fontSize;
  final FontWeight weight;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? letterSpacing;

  const StaffTag(
    this.text, {
    super.key,
    required this.tone,
    this.fontSize = 11,
    this.weight = FontWeight.w700,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.radius = 6,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final c = StaffPalette.of(context).tone(tone);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: staffBody(
          fontSize,
          weight: weight,
          color: c.fg,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}

class StaffDot extends StatelessWidget {
  final Color color;
  final double size;
  const StaffDot(this.color, {super.key, this.size = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class StaffInitialsAvatar extends StatelessWidget {
  final String initials;
  final StaffTone tone;
  final double size;
  final double fontSize;

  const StaffInitialsAvatar(
    this.initials, {
    super.key,
    this.tone = StaffTone.indigo,
    this.size = 40,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final c = StaffPalette.of(context).tone(tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
        child: Text(
          initials,
          style: staffBody(fontSize, weight: FontWeight.w800, color: c.fg),
        ),
      ),
    );
  }
}

/// Rounded-square or circular photo avatar from a bundled asset.
class StaffPhoto extends StatelessWidget {
  final String asset;
  final double size;
  final double? radius;
  final Alignment alignment;
  final String? semanticLabel;

  const StaffPhoto(
    this.asset, {
    super.key,
    required this.size,
    this.radius,
    this.alignment = const Alignment(0, -0.7),
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      alignment: alignment,
      cacheWidth: (size * 3).round(),
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (c, e, s) => Container(
        width: size,
        height: size,
        color: const Color(0xFF1E293B),
        child: Icon(Icons.person_rounded, color: const Color(0xFF94A3B8), size: size * 0.5),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size / 2),
      child: img,
    );
  }
}

/// 44×44 icon-only button with tooltip / semantics.
class StaffIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final double size;
  final double radius;
  final double iconSize;
  final String? badge;

  const StaffIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background,
    this.foreground,
    this.size = 44,
    this.radius = 14,
    this.iconSize = 20,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: badge == null ? tooltip : '$tooltip, $badge',
        excludeSemantics: true,
        child: SizedBox(
          width: size < 44 ? 44 : size,
          height: size < 44 ? 44 : size,
          child: Center(
            child: Material(
              color: background ?? Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
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
                      if (badge != null)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16),
                            height: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: staffBody(10, weight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
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

enum StaffButtonKind { primary, secondary, dangerOutline, ghost }

class StaffButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final StaffButtonKind kind;
  final double height;
  final double radius;
  final double fontSize;
  final IconData? icon;
  final bool loading;
  final bool expand;

  const StaffButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = StaffButtonKind.primary,
    this.height = 50,
    this.radius = 14,
    this.fontSize = 15,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    late Color bg;
    late Color fg;
    BorderSide side = BorderSide.none;
    FontWeight weight = FontWeight.w700;
    switch (kind) {
      case StaffButtonKind.primary:
        bg = p.primaryBtn;
        fg = Colors.white;
      case StaffButtonKind.secondary:
        bg = p.chip;
        fg = p.ink;
      case StaffButtonKind.dangerOutline:
        bg = p.card;
        fg = p.dark ? const Color(0xFFFCA5A5) : kStaffDanger;
        side = BorderSide(color: p.dark ? const Color(0x66DC2626) : const Color(0xFFFECACA));
      case StaffButtonKind.ghost:
        bg = Colors.transparent;
        fg = p.inkSoft;
        weight = FontWeight.w600;
    }
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: staffBody(fontSize, weight: weight, color: fg),
                ),
              ),
            ],
          );
    return SizedBox(
      height: height < 44 ? 44 : height,
      width: expand ? double.infinity : null,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// White search field, 48 tall, radius 14.
class StaffSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const StaffSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: staffBody(14, color: p.ink),
              cursorColor: p.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: staffBody(14, color: p.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: 10)
                : StaffIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Clear search',
                    iconSize: 18,
                    foreground: p.muted,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Grey track with white selected segment (Cases tabs).
class StaffSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const StaffSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? p.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: i == selected && !p.dark
                          ? const [
                              BoxShadow(
                                color: Color(0x1A0F172A),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          labels[i],
                          style: staffBody(
                            13,
                            weight: i == selected ? FontWeight.w700 : FontWeight.w600,
                            color: i == selected ? p.ink : p.inkSoft,
                          ),
                        ),
                      ),
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

/// Pill used for filters and selectable chips.
class StaffPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  final Color? textColor;
  final double height;

  /// When true, selection uses teal tint + teal border (form chips);
  /// otherwise navy fill (filter pills).
  final bool tealSelection;

  const StaffPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.textColor,
    this.height = 34,
    this.tealSelection = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final brand = p.tone(StaffTone.brand);
    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;
    if (tealSelection) {
      bg = selected ? brand.bg : p.card;
      fg = selected ? brand.fg : p.ink;
      side = BorderSide(color: selected ? brand.strong : p.line);
    } else {
      bg = selected ? p.primaryBtn : p.card;
      fg = selected ? Colors.white : (textColor ?? p.ink);
    }
    return Semantics(
      selected: selected,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: bg,
            shape: StadiumBorder(side: side),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dot != null) ...[
                      StaffDot(dot!),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: staffBody(
                        13,
                        weight: selected || textColor != null ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page title row: optional back button, title, optional trailing action.
class StaffPageHeader extends StatelessWidget {
  final String title;
  final double fontSize;
  final VoidCallback? onBack;
  final Widget? trailing;

  const StaffPageHeader({
    super.key,
    required this.title,
    this.fontSize = 24,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (onBack != null) ...[
            StaffIconButton(
              icon: Icons.chevron_left_rounded,
              iconSize: 26,
              tooltip: 'Back',
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: staffHeading(fontSize, color: p.ink),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Uppercase section label used in settings-style lists.
class StaffSectionLabel extends StatelessWidget {
  final String text;
  const StaffSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: staffBody(12, weight: FontWeight.w700, color: p.muted, letterSpacing: 0.6),
        ),
      ),
    );
  }
}

/// White grouped list with hairline dividers between rows.
class StaffGroup extends StatelessWidget {
  final List<Widget> children;
  const StaffGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, color: p.divider));
      items.add(children[i]);
    }
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

/// Settings-style navigation row.
class StaffNavRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final StaffTone iconTone;
  final VoidCallback onTap;

  const StaffNavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconTone = StaffTone.brand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final t = p.tone(iconTone);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: p.dark ? t.fg : t.strong),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: staffBody(15, weight: FontWeight.w600, color: p.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: staffBody(12, color: p.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings-style switch row.
class StaffSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final StaffTone iconTone;

  const StaffSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
    this.iconTone = StaffTone.brand,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final t = p.tone(iconTone);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: t.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: p.dark ? t.fg : t.strong),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: staffBody(15, weight: FontWeight.w600, color: p.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: staffBody(12, color: p.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.brand,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: p.track,
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Forms ───

InputDecoration staffInputDecoration(
  BuildContext context, {
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  double radius = 14,
  Color? fill,
  EdgeInsetsGeometry? contentPadding,
}) {
  final p = StaffPalette.of(context);
  OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: staffBody(15, color: p.faint),
    prefixIcon: prefixIcon,
    prefixIconColor: WidgetStateColor.resolveWith(
      (s) => s.contains(WidgetState.focused) ? p.accent : p.muted,
    ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fill ?? p.card,
    isDense: true,
    contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(p.line, 1),
    enabledBorder: b(p.line, 1),
    focusedBorder: b(p.accent, 2),
    errorBorder: b(StaffPalette.of(context).tone(StaffTone.danger).strong, 1),
    focusedErrorBorder: b(StaffPalette.of(context).tone(StaffTone.danger).strong, 2),
  );
}

/// Label above a form control.
class StaffField extends StatelessWidget {
  final String label;
  final Widget child;
  final Widget? helper;
  final FontWeight weight;

  const StaffField({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.weight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: staffBody(13, weight: weight, color: p.ink)),
        const SizedBox(height: 6),
        child,
        if (helper != null) ...[const SizedBox(height: 6), helper!],
      ],
    );
  }
}

/// Dropdown styled as a staff form field.
class StaffSelect<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? icon;
  final double height;
  final double radius;

  const StaffSelect({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.icon,
    this.height = 48,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Container(
      height: height,
      padding: EdgeInsets.only(left: icon != null ? 14 : 12, right: 8),
      decoration: BoxDecoration(
        color: p.card,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: p.muted),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: p.card,
                borderRadius: BorderRadius.circular(14),
                icon: Icon(Icons.expand_more_rounded, color: p.muted),
                style: staffBody(15, color: p.ink),
                items: [
                  for (final it in items)
                    DropdownMenuItem<T>(
                      value: it,
                      child: Text(labelOf(it), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Modals ───

/// Shows a staff-styled bottom sheet with drag handle (radius 28 top).
Future<T?> showStaffSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool tall = false,
}) {
  final p = StaffPalette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: p.card,
    barrierColor: const Color(0x8C0F172A),
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final content = Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: StaffPalette.of(ctx).handle,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      );
      if (!tall) return content;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: content,
      );
    },
  );
}

/// Shows a staff-styled centred dialog (radius 24).
Future<T?> showStaffDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x990F172A),
    builder: (ctx) => Dialog(
      backgroundColor: StaffPalette.of(ctx).card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: builder(ctx),
      ),
    ),
  );
}

void showStaffSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: staffBody(14, weight: FontWeight.w500, color: Colors.white)),
        backgroundColor: AppColors.staffNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
