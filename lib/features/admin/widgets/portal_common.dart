import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

// ─── Formatting ───

/// "just now", "12 min ago", "3 h ago", "2 d ago", else "4 Mar".
String relativeTime(String? iso, {DateTime? now}) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final diff = (now ?? DateTime.now()).toUtc().difference(t.toUtc());
  if (diff.inSeconds < 60) return 'just now'; // includes small clock skew
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat('d MMM yyyy').format(t.toLocal());
}

String levelLabel(String level) => switch (level) {
      'urgent' => 'Urgent',
      'doctor' => 'See a doctor',
      'pharmacist' => 'Pharmacist',
      'self_care' => 'Self-care',
      _ => 'Routine',
    };

StaffTone levelTone(String level) => switch (level) {
      'urgent' => StaffTone.danger,
      'doctor' => StaffTone.amber,
      'pharmacist' => StaffTone.sky,
      'self_care' => StaffTone.green,
      _ => StaffTone.neutral,
    };

String caseStatusLabel(String s) => switch (s) {
      'waiting' => 'Waiting',
      'treatment' => 'In treatment',
      'discharged' => 'Discharged',
      _ => s,
    };

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && !p.endsWith('.')).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String ageSex(int? age, String? sex) {
  final bits = <String>[
    if (age != null) '$age y',
    if (sex != null && sex.isNotEmpty) sex[0].toUpperCase() + sex.substring(1),
  ];
  return bits.join(' · ');
}

// ─── Actions ───

/// Runs an API call, showing the server's message in a snackbar on failure
/// and [success] on success. Returns the result, or null on failure.
Future<T?> runPortalAction<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final r = await action();
    if (success != null && context.mounted) showStaffSnack(context, success);
    return r;
  } catch (e) {
    if (context.mounted) {
      showStaffSnack(context, apiErrorMessage(e));
    } else {
      messenger?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
    return null;
  }
}

// ─── States ───

class PortalEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const PortalEmpty({super.key, required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, size: 26, color: p.muted),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: staffHeading(16, weight: FontWeight.w700, color: p.ink)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: staffBody(13, color: p.muted, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class PortalError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const PortalError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final t = p.tone(StaffTone.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.cloud_off_rounded, size: 26, color: t.strong),
          ),
          const SizedBox(height: 14),
          Text("Couldn't load this", style: staffHeading(16, weight: FontWeight.w700, color: p.ink)),
          const SizedBox(height: 6),
          Text(apiErrorMessage(error), textAlign: TextAlign.center, style: staffBody(13, color: p.muted, height: 1.45)),
          const SizedBox(height: 16),
          StaffButton('Retry', icon: Icons.refresh_rounded, expand: false, height: 44, onPressed: onRetry),
        ],
      ),
    );
  }
}

class PortalLoading extends StatelessWidget {
  const PortalLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Semantics(
            label: 'Loading',
            child: CircularProgressIndicator(strokeWidth: 2.6, color: StaffPalette.of(context).accent),
          ),
        ),
      );
}

/// A pull-to-refresh list driven by an [AsyncValue]. Loading and error states
/// live inside the scrollable so pull-to-refresh always works.
class PortalAsyncList<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final List<Widget> Function(T data) builder;
  final List<Widget> header;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const PortalAsyncList({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.header = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 32),
    this.maxWidth = 860,
  });

  @override
  Widget build(BuildContext context) {
    final body = value.when(
      data: builder,
      loading: () => const [PortalLoading()],
      error: (e, _) => [PortalError(error: e, onRetry: onRefresh)],
    );
    return RefreshIndicator(
      color: StaffPalette.of(context).accent,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: padding,
        children: [
          StaffContent(
            maxWidth: maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...header, ...body],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calls [onTick] every [interval] while [active] and the app is in the
/// foreground.
class AutoRefresh extends StatefulWidget {
  final bool active;
  final Duration interval;
  final VoidCallback onTick;
  final Widget child;

  const AutoRefresh({
    super.key,
    required this.active,
    required this.onTick,
    required this.child,
    this.interval = const Duration(seconds: 30),
  });

  @override
  State<AutoRefresh> createState() => _AutoRefreshState();
}

class _AutoRefreshState extends State<AutoRefresh> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (s) {
      final fg = s == AppLifecycleState.resumed;
      if (fg && !_foreground && widget.active) widget.onTick();
      _foreground = fg;
      _sync();
    });
    _sync();
  }

  @override
  void didUpdateWidget(AutoRefresh old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) widget.onTick();
    if (old.active != widget.active || old.interval != widget.interval) _sync(restart: true);
  }

  void _sync({bool restart = false}) {
    final run = widget.active && _foreground;
    if (!run || restart) {
      _timer?.cancel();
      _timer = null;
    }
    if (run && _timer == null) {
      _timer = Timer.periodic(widget.interval, (_) => widget.onTick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── Building blocks ───

/// Navy page header used across the portal.
class PortalHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final Widget? bottom;

  const PortalHeader({super.key, required this.title, this.subtitle, this.trailing, this.onBack, this.bottom});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      color: AppColors.staffNavy,
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, bottom == null ? 18 : 14),
      child: StaffContent(
        maxWidth: 860,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (onBack != null) ...[
                  StaffIconButton(
                    icon: Icons.chevron_left_rounded,
                    iconSize: 26,
                    tooltip: 'Back',
                    background: const Color(0x14FFFFFF),
                    foreground: const Color(0xFFF1F5F9),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: staffHeading(22, color: const Color(0xFFF1F5F9))),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: staffBody(13, color: const Color(0xFF94A3B8))),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (bottom != null) ...[const SizedBox(height: 14), bottom!],
          ],
        ),
      ),
    );
  }
}

/// White icon button for use on the navy header.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? badge;
  const HeaderIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.badge});

  @override
  Widget build(BuildContext context) => StaffIconButton(
        icon: icon,
        tooltip: tooltip,
        badge: badge,
        background: const Color(0x14FFFFFF),
        foreground: const Color(0xFFF1F5F9),
        onPressed: onPressed,
      );
}

/// Section title with optional trailing action.
class PortalSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const PortalSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: staffHeading(16, weight: FontWeight.w700, color: p.ink)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Key / value row used in detail cards.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final StaffTone? tone;
  const InfoRow(this.label, this.value, {super.key, this.tone});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: staffBody(13, color: p.muted))),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: staffBody(14,
                  weight: FontWeight.w600, color: tone == null ? p.ink : p.tone(tone!).fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrap of small chips for lists like allergies.
class ChipList extends StatelessWidget {
  final List<String> items;
  final StaffTone tone;
  final String emptyText;
  const ChipList(this.items, {super.key, this.tone = StaffTone.neutral, this.emptyText = 'None reported'});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyText, style: staffBody(13, color: StaffPalette.of(context).muted));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final i in items) StaffTag(i, tone: tone, fontSize: 12, weight: FontWeight.w600)],
    );
  }
}

/// Standard sheet layout: title, scrollable body, action bar.
class PortalSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  const PortalSheet({super.key, required this.title, this.subtitle, required this.children, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: staffHeading(20, color: p.ink))),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: staffBody(13, color: p.muted)),
              ],
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Text field with the staff look.
class PortalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final Key? fieldKey;

  const PortalTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.capitalization = TextCapitalization.sentences,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return StaffField(
      label: label,
      child: TextField(
        key: fieldKey,
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 2 : 1,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        style: staffBody(15, color: p.ink),
        decoration: staffInputDecoration(context, hint: hint),
      ),
    );
  }
}

/// Avatar + name + role row for a team member.
class TeamMemberTile extends StatelessWidget {
  final TeamMember member;
  final Widget? trailing;
  final VoidCallback? onTap;
  const TeamMemberTile({super.key, required this.member, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final sub = [member.role.label, if ((member.department ?? '').isNotEmpty) member.department!].join(' · ');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  StaffInitialsAvatar(initialsOf(member.fullName),
                      tone: member.role == StaffRole.nurse ? StaffTone.pink : StaffTone.indigo),
                  if (member.onDuty)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: p.card, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.fullName, style: staffBody(15, weight: FontWeight.w600, color: p.ink)),
                    const SizedBox(height: 2),
                    Text(member.onDuty ? '$sub · On duty' : sub, style: staffBody(12, color: p.muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Small numeric stepper (44px targets).
class CountStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;
  const CountStepper({super.key, required this.label, required this.value, required this.onChanged, this.min = 0, this.max});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: staffBody(14, weight: FontWeight.w600, color: p.ink))),
        StaffIconButton(
          icon: Icons.remove_rounded,
          tooltip: 'Decrease $label',
          background: p.chip,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 52,
          child: Text('$value',
              textAlign: TextAlign.center, style: staffHeading(18, weight: FontWeight.w700, color: p.ink)),
        ),
        StaffIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Increase $label',
          background: p.chip,
          onPressed: max == null || value < max! ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Occupancy bar for wards / equipment.
class OccupancyBar extends StatelessWidget {
  final int used;
  final int total;
  const OccupancyBar({super.key, required this.used, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final tone = ratio >= 0.9 ? StaffTone.danger : (ratio >= 0.7 ? StaffTone.amber : StaffTone.green);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 8,
        backgroundColor: p.track,
        color: p.tone(tone).strong,
        semanticsLabel: '$used of $total in use',
      ),
    );
  }
}

/// Two-option confirmation dialog. Returns true when confirmed.
Future<bool> confirmPortal(BuildContext context,
    {required String title, required String message, required String confirm, bool destructive = false}) async {
  final r = await showStaffDialog<bool>(
    context,
    builder: (ctx) {
      final p = StaffPalette.of(ctx);
      return Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: staffHeading(19, color: p.ink)),
            const SizedBox(height: 8),
            Text(message, style: staffBody(14, color: p.inkSoft, height: 1.5)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StaffButton('Cancel',
                      kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(ctx).pop(false)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StaffButton(confirm,
                      kind: destructive ? StaffButtonKind.dangerOutline : StaffButtonKind.primary,
                      onPressed: () => Navigator.of(ctx).pop(true)),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return r ?? false;
}
