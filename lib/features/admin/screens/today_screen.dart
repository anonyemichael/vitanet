import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/portal_shell.dart';
import 'package:vitanet/features/admin/screens/referrals_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Home: who is signed in, duty status, live counts and incoming referrals.
class TodayScreen extends ConsumerStatefulWidget {
  final bool active;
  final ValueChanged<PortalTab>? onOpenTab;
  const TodayScreen({super.key, this.active = true, this.onOpenTab});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _savingDuty = false;

  Future<void> _setDuty(bool v) async {
    setState(() => _savingDuty = true);
    final r = await runPortalAction(context, () => ref.read(hospitalApiProvider).setDuty(v),
        success: v ? "You're on duty." : "You're off duty.");
    if (!mounted) return;
    setState(() => _savingDuty = false);
    if (r != null) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(capacityProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardProvider);
    final me = ref.watch(portalMeProvider);
    final alerts = ref.watch(alertsProvider).valueOrNull?.length ?? 0;
    final d = dash.valueOrNull;
    final name = d?.myName.isNotEmpty == true ? d!.myName : (me?.fullName ?? '');
    final subtitle = [
      if ((me?.department ?? '').isNotEmpty) me!.department!,
      if (me != null) me.role.label,
    ].join(' · ');
    return Column(
      children: [
        PortalHeader(
          leading: _Avatar(name: name),
          title: name.isEmpty ? 'Home' : name,
          subtitle: subtitle.isEmpty ? null : subtitle,
          trailing: widget.onOpenTab == null
              ? null
              : HeaderIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Alerts',
                  badge: alerts > 0 ? '$alerts' : null,
                  onPressed: () => widget.onOpenTab!(PortalTab.alerts),
                ),
          bottom: d == null ? null : _DutyBanner(onDuty: d.onDuty, saving: _savingDuty, onChanged: _setDuty),
        ),
        Expanded(
          child: PortalAsyncList<Dashboard>(
            value: dash,
            onRefresh: () => ref.refresh(dashboardProvider.future),
            builder: (d) => [
              _CountsGrid(counts: d.counts, onOpenTab: widget.onOpenTab),
              PortalSectionTitle(
                'Incoming from VitaNet',
                trailing: widget.onOpenTab == null
                    ? null
                    : TextButton(
                        onPressed: () => widget.onOpenTab!(PortalTab.referrals),
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                        child: const Text('View all'),
                      ),
              ),
              if (d.incoming.isEmpty)
                const StaffCard(
                  child: PortalEmpty(
                    icon: Icons.move_to_inbox_outlined,
                    title: 'No incoming referrals yet',
                    message: 'When a patient sends their VitaNet summary to this hospital it appears here.',
                  ),
                )
              else
                for (final r in d.incoming) ...[
                  ReferralCard(referral: r, onTap: () => openReferral(context, r.id)),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Initials tile; staff accounts have no photo field.
class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.split(' ').where((s) => s.isNotEmpty && !s.endsWith('.')).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFF0F766E), borderRadius: BorderRadius.circular(16)),
      child: Text(initials, style: staffHeading(18, color: Colors.white)),
    );
  }
}

/// Duty status with the current date and time, as designed, plus the toggle.
class _DutyBanner extends StatelessWidget {
  final bool onDuty;
  final bool saving;
  final ValueChanged<bool> onChanged;
  const _DutyBanner({required this.onDuty, required this.saving, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('EEE d MMM · HH:mm').format(DateTime.now());
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        decoration: BoxDecoration(
          color: onDuty ? const Color(0x1A2DD4BF) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onDuty ? const Color(0x552DD4BF) : const Color(0x22FFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: onDuty ? const Color(0xFF34D399) : const Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(onDuty ? 'On shift' : 'Off shift',
                  style: staffBody(14,
                      weight: FontWeight.w700,
                      color: onDuty ? const Color(0xFF5EEAD4) : const Color(0xFFF1F5F9))),
            ),
            Text(now, style: staffBody(13, color: const Color(0xFF94A3B8))),
            if (saving)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              )
            else
              Switch(
                value: onDuty,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF0F766E),
              ),
          ],
        ),
      ),
    );
  }
}

/// The design's four cards: active cases, urgent incoming, beds, staff.
class _CountsGrid extends StatelessWidget {
  final DashboardCounts counts;
  final ValueChanged<PortalTab>? onOpenTab;
  const _CountsGrid({required this.counts, this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final bedsUsed = counts.bedsTotal == 0 ? 0.0 : 1 - counts.bedsFree / counts.bedsTotal;
    final tiles = <Widget>[
      _StatTile(
        label: 'Active cases',
        value: '${counts.waiting + counts.inTreatment}',
        hint: '${counts.waiting} waiting',
        hintTone: StaffTone.green,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.cases),
      ),
      _StatTile(
        label: 'Urgent incoming',
        value: '${counts.incomingUrgent}',
        hint: '${counts.incoming} incoming',
        hintTone: StaffTone.danger,
        critical: counts.incomingUrgent > 0,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.referrals),
      ),
      _StatTile(
        label: 'Beds free',
        value: '${counts.bedsFree}',
        suffix: '/ ${counts.bedsTotal}',
        progress: counts.bedsTotal == 0 ? null : bedsUsed,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.hospital),
      ),
      _StatTile(
        label: 'Staff on duty',
        value: '${counts.staffOnDuty}',
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.hospital),
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final String? hint;
  final StaffTone hintTone;
  final double? progress;
  final bool critical;
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    this.suffix,
    this.hint,
    this.hintTone = StaffTone.green,
    this.progress,
    this.critical = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final danger = p.tone(StaffTone.danger);
    final hintColor = p.tone(hintTone).fg;
    return StaffTap(
      onTap: onTap,
      color: p.card,
      radius: 20,
      semanticLabel: '$label: $value${suffix == null ? '' : ' $suffix'}${hint == null ? '' : ', $hint'}',
      child: Container(
        decoration: critical
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: danger.bg, width: 1.5),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: staffBody(13,
                    weight: FontWeight.w600, color: critical ? danger.fg : p.muted)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: staffHeading(30, color: critical ? danger.fg : p.ink)),
                if (suffix != null) ...[
                  const SizedBox(width: 4),
                  Text(suffix!, style: staffBody(15, color: p.muted)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: p.line,
                  color: progress! > 0.85 ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                ),
              )
            else if (hint != null)
              Text(hint!, style: staffBody(13, weight: FontWeight.w600, color: hintColor)),
          ],
        ),
      ),
    );
  }
}
