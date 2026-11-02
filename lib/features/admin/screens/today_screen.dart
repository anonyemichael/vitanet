import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/case_record_screen.dart';
import 'package:vitanet/features/admin/screens/cases_screen.dart';
import 'package:vitanet/features/admin/screens/portal_shell.dart';
import 'package:vitanet/features/admin/screens/referrals_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Today: live counts, incoming referrals, my cases, on-duty toggle.
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

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardProvider);
    final me = ref.watch(portalMeProvider);
    final d = dash.valueOrNull;
    final name = d?.myName.isNotEmpty == true ? d!.myName : (me?.fullName ?? '');
    final firstName = name.split(' ').where((s) => s.isNotEmpty && !s.endsWith('.')).firstOrNull ?? name;
    return Column(
      children: [
        PortalHeader(
          title: '${_greeting()}${firstName.isEmpty ? '' : ', $firstName'}',
          subtitle: me == null ? null : '${me.role.label}${(me.department ?? '').isEmpty ? '' : ' · ${me.department}'}',
          trailing: widget.onOpenTab == null
              ? null
              : HeaderIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Alerts',
                  onPressed: () => widget.onOpenTab!(PortalTab.alerts),
                ),
          bottom: d == null ? null : _DutyBanner(onDuty: d.onDuty, saving: _savingDuty, onChanged: _setDuty),
        ),
        Expanded(
          child: PortalAsyncList<Dashboard>(
            value: dash,
            onRefresh: () => ref.refresh(dashboardProvider.future),
            builder: (d) => [
              _CountsGrid(counts: d.counts, isAdmin: me?.isAdmin ?? false, onOpenTab: widget.onOpenTab),
              PortalSectionTitle(
                'Incoming referrals',
                trailing: widget.onOpenTab == null
                    ? null
                    : TextButton(
                        onPressed: () => widget.onOpenTab!(PortalTab.referrals),
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                        child: const Text('See all'),
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
              const PortalSectionTitle('My cases'),
              if (d.myCases.isEmpty)
                const StaffCard(
                  child: PortalEmpty(
                    icon: Icons.assignment_ind_outlined,
                    title: 'No open cases assigned to you',
                    message: 'Cases you are assigned to show here until they are discharged.',
                  ),
                )
              else
                for (final c in d.myCases) ...[
                  CaseCard(portalCase: c, onTap: () => openCase(context, c.id)),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DutyBanner extends StatelessWidget {
  final bool onDuty;
  final bool saving;
  final ValueChanged<bool> onChanged;
  const _DutyBanner({required this.onDuty, required this.saving, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(14)),
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
              child: Text(onDuty ? 'On duty' : 'Off duty',
                  style: staffBody(14, weight: FontWeight.w600, color: const Color(0xFFF1F5F9))),
            ),
            if (saving)
              const Padding(
                padding: EdgeInsets.all(12),
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

class _CountsGrid extends StatelessWidget {
  final DashboardCounts counts;
  final bool isAdmin;
  final ValueChanged<PortalTab>? onOpenTab;
  const _CountsGrid({required this.counts, required this.isAdmin, this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatTile(
        label: 'Incoming',
        value: '${counts.incoming}',
        hint: counts.incomingUrgent > 0 ? '${counts.incomingUrgent} urgent' : null,
        tone: counts.incomingUrgent > 0 ? StaffTone.danger : StaffTone.brand,
        icon: Icons.move_to_inbox_outlined,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.referrals),
      ),
      _StatTile(
        label: 'Waiting',
        value: '${counts.waiting}',
        tone: StaffTone.amber,
        icon: Icons.hourglass_top_rounded,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.cases),
      ),
      _StatTile(
        label: 'In treatment',
        value: '${counts.inTreatment}',
        tone: StaffTone.indigo,
        icon: Icons.healing_outlined,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.cases),
      ),
      _StatTile(
        label: 'Beds free',
        value: '${counts.bedsFree}',
        hint: 'of ${counts.bedsTotal}',
        tone: StaffTone.green,
        icon: Icons.bed_outlined,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.hospital),
      ),
      _StatTile(
        label: 'Staff on duty',
        value: '${counts.staffOnDuty}',
        tone: StaffTone.sky,
        icon: Icons.badge_outlined,
        onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.hospital),
      ),
      if (isAdmin)
        _StatTile(
          label: 'Staff requests',
          value: '${counts.pendingStaff}',
          tone: counts.pendingStaff > 0 ? StaffTone.violet : StaffTone.neutral,
          icon: Icons.person_add_alt_outlined,
          onTap: onOpenTab == null ? null : () => onOpenTab!(PortalTab.team),
        ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 640 ? 3 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final StaffTone tone;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatTile({required this.label, required this.value, this.hint, required this.tone, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final t = p.tone(tone);
    return StaffTap(
      onTap: onTap,
      color: p.card,
      radius: 16,
      semanticLabel: '$label: $value${hint == null ? '' : ', $hint'}',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: p.dark ? t.fg : t.strong),
                ),
                const Spacer(),
                if (hint != null)
                  Flexible(
                    child: Text(hint!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: staffBody(11, weight: FontWeight.w700, color: t.fg)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: staffHeading(26, color: p.ink)),
            Text(label, style: staffBody(12, weight: FontWeight.w600, color: p.muted)),
          ],
        ),
      ),
    );
  }
}
