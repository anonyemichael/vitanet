/// The hospital portal's own visual system ("clinical"): calm slate surfaces,
/// a navy rail on desk, and triage colour as the only loud colour. Light and
/// dark follow the app theme. Mockups: the "VitaNet Hospital Portal" canvas.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/features/portal/data/hospital_api_service.dart';

// ─── Palette ───

class ClinicalPalette {
  final bool dark;
  final Color bg, card, line, divider, ink, body, muted, faint, fill, track;
  final Color primary, onPrimary, primaryTint, primaryInk, navy, navyRaised, navyMuted;

  const ClinicalPalette._({
    required this.dark,
    required this.bg,
    required this.card,
    required this.line,
    required this.divider,
    required this.ink,
    required this.body,
    required this.muted,
    required this.faint,
    required this.fill,
    required this.track,
    required this.primary,
    required this.onPrimary,
    required this.primaryTint,
    required this.primaryInk,
    required this.navy,
    required this.navyRaised,
    required this.navyMuted,
  });

  static const light = ClinicalPalette._(
    dark: false,
    bg: Color(0xFFF3F5F8),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE2E7EE),
    divider: Color(0xFFEEF1F5),
    ink: Color(0xFF0E1726),
    body: Color(0xFF334155),
    muted: Color(0xFF5B6676),
    faint: Color(0xFF8A94A3),
    fill: Color(0xFFF1F4F8),
    track: Color(0xFFE4E9F0),
    primary: Color(0xFF1F5FD1),
    onPrimary: Color(0xFFFFFFFF),
    primaryTint: Color(0xFFEEF4FF),
    primaryInk: Color(0xFF1A3E7A),
    navy: Color(0xFF0B1E33),
    navyRaised: Color(0xFF1E3A5C),
    navyMuted: Color(0xFFB8C4D3),
  );

  static const darkPalette = ClinicalPalette._(
    dark: true,
    bg: Color(0xFF0B121C),
    card: Color(0xFF131C28),
    line: Color(0xFF223042),
    divider: Color(0xFF1A2533),
    ink: Color(0xFFE8EDF4),
    body: Color(0xFFC3CCD8),
    muted: Color(0xFF93A0B2),
    faint: Color(0xFF6B7889),
    fill: Color(0xFF1A2533),
    track: Color(0xFF1A2533),
    primary: Color(0xFF3B7BF0),
    onPrimary: Color(0xFFFFFFFF),
    primaryTint: Color(0xFF172A4A),
    primaryInk: Color(0xFFA9C9FF),
    navy: Color(0xFF0F1824),
    navyRaised: Color(0xFF1E3A5C),
    navyMuted: Color(0xFF93A6BD),
  );

  static ClinicalPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPalette : light;

  ToneColors tone(Tone t) => dark ? t.darkColors : t.lightColors;
}

class ToneColors {
  final Color bg, fg, dot, border;
  const ToneColors(this.bg, this.fg, this.dot, this.border);
}

/// Red is for life-threatening, orange for "act soon", amber for "a doctor
/// today", green for routine. Blue and neutral are informational.
enum Tone {
  red(ToneColors(Color(0xFFFDECEC), Color(0xFF8E1616), Color(0xFFB91C1C), Color(0xFFF6C9C9)),
      ToneColors(Color(0xFF3A1416), Color(0xFFFCA5A5), Color(0xFFEF4444), Color(0xFF5C2226))),
  orange(ToneColors(Color(0xFFFFF1E7), Color(0xFF8A2E07), Color(0xFFC2410C), Color(0xFFF8D2B8)),
      ToneColors(Color(0xFF3A2010), Color(0xFFFDBA8C), Color(0xFFF97316), Color(0xFF5A3418))),
  amber(ToneColors(Color(0xFFFEF7E0), Color(0xFF7A4A05), Color(0xFFA16207), Color(0xFFF3DE9C)),
      ToneColors(Color(0xFF33290E), Color(0xFFFCD98A), Color(0xFFEAB308), Color(0xFF524318))),
  green(ToneColors(Color(0xFFEAF6EE), Color(0xFF14632F), Color(0xFF15803D), Color(0xFFBFE3CB)),
      ToneColors(Color(0xFF0F2E1C), Color(0xFF86EFAC), Color(0xFF22C55E), Color(0xFF1C4A2E))),
  blue(ToneColors(Color(0xFFE8EEF8), Color(0xFF1A3E7A), Color(0xFF1F5FD1), Color(0xFFC9D9F8)),
      ToneColors(Color(0xFF172A4A), Color(0xFFA9C9FF), Color(0xFF3B7BF0), Color(0xFF26406B))),
  neutral(ToneColors(Color(0xFFF1F4F8), Color(0xFF334155), Color(0xFF8A94A3), Color(0xFFE2E7EE)),
      ToneColors(Color(0xFF1A2533), Color(0xFFC3CCD8), Color(0xFF6B7889), Color(0xFF223042)));

  final ToneColors lightColors;
  final ToneColors darkColors;
  const Tone(this.lightColors, this.darkColors);
}

// ─── Clinical vocabulary ───

Tone levelTone(String level) => switch (level) {
      'urgent' => Tone.red,
      'doctor' => Tone.amber,
      _ => Tone.green,
    };

String levelLabel(String level) => switch (level) {
      'urgent' => 'Urgent',
      'doctor' => 'Doctor',
      'pharmacist' => 'Pharmacist',
      'self_care' => 'Self-care',
      _ => 'Routine',
    };

String caseStatusLabel(String status) => switch (status) {
      'expected' => 'On the way',
      'waiting' => 'Waiting',
      'treatment' => 'In treatment',
      'discharged' => 'Discharged',
      _ => status,
    };

Tone caseStatusTone(String status) => switch (status) {
      'expected' => Tone.blue,
      'waiting' => Tone.amber,
      'treatment' => Tone.green,
      _ => Tone.neutral,
    };

String outcomeLabel(String? outcome) => switch (outcome) {
      'home' => 'Home',
      'admitted' => 'Admitted',
      'transferred' => 'Transferred',
      'left' => 'Left early',
      _ => 'Discharged',
    };

/// Early-warning score colour: 7+ red, 5–6 orange, 1–4 amber, 0 neutral.
Tone earlyWarningTone(int? score) => score == null
    ? Tone.neutral
    : score >= 7
        ? Tone.red
        : score >= 5
            ? Tone.orange
            : score >= 1
                ? Tone.amber
                : Tone.green;

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && !p.endsWith('.')).toList();
  if (parts.isEmpty) return '–';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// "62 M", "35 F", "62", or "".
String ageSex(int? age, String? sex) {
  final s = (sex ?? '').trim();
  final letter = s.isEmpty ? '' : s[0].toUpperCase();
  return [if (age != null) '$age', if (letter.isNotEmpty) letter].join(' ');
}

/// Short case number shown to staff, e.g. C-3F2A1B.
String caseRef(String id) {
  final compact = id.replaceAll('-', '');
  if (compact.isEmpty) return 'C-–';
  return 'C-${compact.substring(0, compact.length < 6 ? compact.length : 6).toUpperCase()}';
}

DateTime? parseTime(String? iso) => DateTime.tryParse(iso ?? '')?.toLocal();

/// "09:46" today, "Mon 09:46" this week, else "4 Mar".
String clockTime(String? iso, {DateTime? now}) {
  final t = parseTime(iso);
  if (t == null) return '';
  final n = now ?? DateTime.now();
  if (t.year == n.year && t.month == n.month && t.day == n.day) return DateFormat('HH:mm').format(t);
  if (n.difference(t).inDays < 6) return DateFormat('EEE HH:mm').format(t);
  return DateFormat('d MMM').format(t);
}

/// "5m", "48m", "1h12", "2d" since [iso].
String elapsed(String? iso, {DateTime? now}) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return '';
  final d = (now ?? DateTime.now()).toUtc().difference(t.toUtc());
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  return '${d.inDays}d';
}

bool isToday(String? iso, {DateTime? now}) {
  final t = parseTime(iso);
  final n = now ?? DateTime.now();
  return t != null && t.year == n.year && t.month == n.month && t.day == n.day;
}

// ─── Type ───

TextStyle cText(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height, double? letterSpacing}) =>
    GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);

/// Monospaced, tabular figures for times, ETAs and readings.
TextStyle cMono(double size, {FontWeight weight = FontWeight.w600, Color? color}) => GoogleFonts.ibmPlexMono(
    fontSize: size, fontWeight: weight, color: color, fontFeatures: const [FontFeature.tabularFigures()]);

// ─── Building blocks ───

class CCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final String? semanticLabel;

  const CCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 14,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? p.line),
    );
    final content = Padding(padding: padding, child: child);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: color ?? p.card,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class CChip extends StatelessWidget {
  final String label;
  final Tone tone;
  final bool dot;
  final bool bordered;
  final double height;

  const CChip(this.label, {super.key, this.tone = Tone.neutral, this.dot = false, this.bordered = false, this.height = 24});

  @override
  Widget build(BuildContext context) {
    final t = ClinicalPalette.of(context).tone(tone);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(6),
        border: bordered ? Border.all(color: t.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[CDot(t.dot, size: 7), const SizedBox(width: 6)],
          Flexible(
            child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: cText(12, weight: FontWeight.w600, color: t.fg)),
          ),
        ],
      ),
    );
  }
}

class CDot extends StatelessWidget {
  final Color color;
  final double size;
  const CDot(this.color, {super.key, this.size = 10});

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class LevelChip extends StatelessWidget {
  final String level;
  const LevelChip(this.level, {super.key});

  @override
  Widget build(BuildContext context) => CChip(levelLabel(level), tone: levelTone(level), dot: true);
}

enum CButtonKind { primary, secondary, danger, dark, ghost, tint }

class CButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CButtonKind kind;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;
  final double fontSize;

  const CButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = CButtonKind.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 48,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final red = p.tone(Tone.red);
    final (Color bg, Color fg, Color? border) = switch (kind) {
      CButtonKind.primary => (p.primary, p.onPrimary, null),
      CButtonKind.secondary => (p.fill, p.ink, null),
      CButtonKind.danger => (red.dot, Colors.white, null),
      CButtonKind.dark => (p.dark ? p.ink : const Color(0xFF0E1726), p.dark ? p.bg : Colors.white, null),
      CButtonKind.ghost => (Colors.transparent, p.body, null),
      CButtonKind.tint => (p.primaryTint, p.primaryInk, p.tone(Tone.blue).border),
    };
    final disabled = onPressed == null || loading;
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cText(fontSize, weight: FontWeight.w600, color: fg)),
              ),
            ],
          );
    final button = Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height >= 46 ? 12 : 10),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: height < 44 ? 8 : 14),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

class CIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int badge;
  final bool outlined;
  final Color? color;
  final Color? background;

  const CIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
    this.outlined = false,
    this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: badge > 0 ? '$tooltip, $badge new' : tooltip,
        excludeSemantics: true,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: background ?? (outlined ? p.card : Colors.transparent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: outlined ? BorderSide(color: p.line) : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: onPressed, child: Icon(icon, size: 21, color: color ?? p.ink)),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: p.tone(Tone.red).dot, borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: Text(badge > 99 ? '99+' : '$badge', style: cMono(11, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented control used for lanes, filters and small choices.
class CSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;

  const CSegmented({super.key, required this.labels, required this.selected, required this.onChanged, this.height = 38});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                label: labels[i],
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? (p.dark ? const Color(0xFF2A3748) : p.card) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: cText(13, weight: FontWeight.w600, color: i == selected ? p.ink : p.muted)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded pill filter (Patients filters, decline reasons).
class CPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool round;

  const CPill({super.key, required this.label, required this.selected, required this.onTap, this.round = true});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final on = p.dark ? p.ink : const Color(0xFF0E1726);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? on : p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(round ? 20 : 10),
          side: BorderSide(color: selected ? on : p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label,
                style: cText(14, weight: FontWeight.w600, color: selected ? (p.dark ? p.bg : Colors.white) : p.body)),
          ),
        ),
      ),
    );
  }
}

/// A selectable option row (ward, assignee, outcome) with a radio dot.
class COption extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? leading;
  final Color? trailingColor;

  const COption({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.leading,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: selected ? p.primaryTint : p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: selected ? p.primary : p.line, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  leading ??
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? p.primary : p.faint, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: selected ? CDot(p.primary, size: 8) : null,
                      ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: cText(15, weight: FontWeight.w600, color: p.ink)),
                        if (subtitle != null) Text(subtitle!, style: cText(12, color: p.muted)),
                      ],
                    ),
                  ),
                  if (trailing != null) Text(trailing!, style: cMono(13, color: trailingColor ?? p.body)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Tone tone;
  const CAvatar(this.name, {super.key, this.size = 32, this.tone = Tone.blue});

  @override
  Widget build(BuildContext context) {
    final t = ClinicalPalette.of(context).tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(name.isEmpty ? '–' : initialsOf(name),
          style: cText(size * 0.36, weight: FontWeight.w700, color: t.fg)),
    );
  }
}

class CSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const CSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text.toUpperCase(),
                style: cText(11, weight: FontWeight.w700, color: p.muted, letterSpacing: 0.66)),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A compact switch matching the mockups.
class CSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  const CSwitch({super.key, required this.value, required this.onChanged, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      activeTrackColor: activeColor ?? p.tone(Tone.green).dot,
      inactiveTrackColor: p.dark ? const Color(0xFF2A3748) : const Color(0xFFC5CDD8),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

class CTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool mono;
  final String? helper;
  final Color? helperColor;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextCapitalization capitalization;

  const CTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.mono = false,
    this.helper,
    this.helperColor,
    this.autofocus = false,
    this.onChanged,
    this.capitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: cText(13, weight: FontWeight.w600, color: p.body)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 2 : 1,
          keyboardType: keyboardType,
          autofocus: autofocus,
          onChanged: onChanged,
          textCapitalization: capitalization,
          style: mono ? cMono(18, color: p.ink) : cText(15, color: p.ink),
          decoration: cInputDecoration(context, hint: hint),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper!, style: cText(12, color: helperColor ?? p.muted)),
        ],
      ],
    );
  }
}

InputDecoration cInputDecoration(BuildContext context, {String? hint, Widget? prefixIcon}) {
  final p = ClinicalPalette.of(context);
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: cText(15, color: p.faint),
    isDense: true,
    filled: true,
    fillColor: p.card,
    prefixIcon: prefixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: b(p.dark ? p.line : const Color(0xFFCBD3DE)),
    enabledBorder: b(p.dark ? p.line : const Color(0xFFCBD3DE)),
    focusedBorder: b(p.primary, 2),
  );
}

/// A reading tile: label + big tabular value, tinted when out of range.
class VitalTile extends StatelessWidget {
  final String label;
  final String value;
  final Tone? tone;
  const VitalTile({super.key, required this.label, required this.value, this.tone});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final t = tone == null ? null : p.tone(tone!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: t?.bg ?? p.bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: cText(11, weight: FontWeight.w600, color: t?.fg ?? p.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: cMono(18, color: t?.fg ?? p.ink)),
          ),
        ],
      ),
    );
  }
}

// ─── States ───

class CEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const CEmpty({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 24, color: p.muted),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: cText(16, weight: FontWeight.w600, color: p.ink)),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: cText(13, color: p.muted, height: 1.45)),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class CError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const CError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => CEmpty(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this",
        message: apiErrorMessage(error),
        action: CButton('Try again', icon: Icons.refresh_rounded, expand: false, height: 44, onPressed: onRetry),
      );
}

class CLoading extends StatelessWidget {
  const CLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Semantics(
            label: 'Loading',
            child: CircularProgressIndicator(strokeWidth: 2.6, color: ClinicalPalette.of(context).primary),
          ),
        ),
      );
}

// ─── Sheets, dialogs, snackbars ───

/// Bottom sheet on phones; a centred panel on wide screens.
Future<T?> showCSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  final wide = MediaQuery.sizeOf(context).width >= 760;
  final p = ClinicalPalette.of(context);
  if (wide) {
    return showDialog<T>(
      context: context,
      barrierColor: const Color(0x8C0B1E33),
      builder: (ctx) => Dialog(
        backgroundColor: p.card,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.sizeOf(ctx).height * 0.86),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: p.card,
    barrierColor: const Color(0x8C0B1E33),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.92),
        child: builder(ctx),
      ),
    ),
  );
}

/// Standard sheet body: handle, title + close, scrollable content, actions.
class CSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final double gap;

  const CSheet({super.key, required this.title, this.subtitle, required this.children, this.actions = const [], this.gap = 16});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!wide)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, wide ? 18 : 12, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(title, style: cText(20, weight: FontWeight.w700, color: p.ink))),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: cText(13, color: p.muted, height: 1.4)),
                      ),
                  ],
                ),
              ),
              CIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                background: p.fill,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(flex: i == actions.length - 1 && actions.length > 1 ? 2 : 1, child: actions[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

void showCSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: cText(14, color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0E1726),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
}

/// Runs an API call; shows the server's message on failure and [success] on
/// success. Returns the result, or null on failure.
Future<T?> runCAction<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final r = await action();
    if (success != null && context.mounted) showCSnack(context, success);
    return r;
  } catch (e) {
    if (context.mounted) {
      showCSnack(context, apiErrorMessage(e));
    } else {
      messenger?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
    return null;
  }
}

Future<bool> confirmC(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final p = ClinicalPalette.of(ctx);
      return AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: cText(20, weight: FontWeight.w700, color: p.ink)),
        content: Text(message, style: cText(14, color: p.body, height: 1.45)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(child: CButton('Cancel', kind: CButtonKind.secondary, onPressed: () => Navigator.pop(ctx, false))),
              const SizedBox(width: 8),
              Expanded(
                child: CButton(confirm,
                    kind: danger ? CButtonKind.danger : CButtonKind.primary, onPressed: () => Navigator.pop(ctx, true)),
              ),
            ],
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Rebuilds [builder] every [period] (ETA countdowns, "waiting 12m").
class Every extends StatefulWidget {
  final Duration period;
  final WidgetBuilder builder;
  const Every({super.key, this.period = const Duration(seconds: 30), required this.builder});

  @override
  State<Every> createState() => _EveryState();
}

class _EveryState extends State<Every> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.period, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// "6 min", "Due now", "5 min late" for an incoming patient.
String etaText(int? minutes) {
  if (minutes == null) return '—';
  if (minutes > 0) return '$minutes min';
  if (minutes == 0) return 'Due now';
  return '${-minutes} min late';
}
