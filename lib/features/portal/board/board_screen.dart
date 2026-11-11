import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/alerts/alerts_screen.dart';
import 'package:vitanet/features/portal/board/referral_view.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/record/case_record_view.dart';
import 'package:vitanet/features/portal/shell/portal_nav.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

const _incomingKey = 'new';
const _activeQuery = (status: activeCaseStatuses, mine: false);
const _dischargedQuery = (status: 'discharged', mine: false);

/// Sort: most urgent first, then soonest / longest waiting.
int _levelRank(String level) => switch (level) {
      'urgent' => 0,
      'doctor' => 1,
      _ => 2,
    };

/// Everything the Board shows, from the live providers.
class _BoardData {
  final List<Referral> incoming;
  final List<PortalCase> expected;
  final List<PortalCase> inHospital;
  final List<PortalCase> dischargedToday;
  const _BoardData(this.incoming, this.expected, this.inHospital, this.dischargedToday);

  static _BoardData of(WidgetRef ref) {
    final incoming = [...?ref.watch(referralsProvider(_incomingKey)).valueOrNull]..sort((a, b) {
        final l = _levelRank(a.triageLevel).compareTo(_levelRank(b.triageLevel));
        if (l != 0) return l;
        return (a.minutesToArrival() ?? 999).compareTo(b.minutesToArrival() ?? 999);
      });
    final active = ref.watch(casesProvider(_activeQuery)).valueOrNull ?? const <PortalCase>[];
    final expected = active.where((c) => c.isExpected).toList();
    final inHospital = active.where((c) => !c.isExpected).toList()..sort((a, b) {
        final l = _levelRank(a.level).compareTo(_levelRank(b.level));
        if (l != 0) return l;
        return (a.arrivedAt ?? a.createdAt).compareTo(b.arrivedAt ?? b.createdAt);
      });
    final discharged = (ref.watch(casesProvider(_dischargedQuery)).valueOrNull ?? const <PortalCase>[])
        .where((c) => isToday(c.updatedAt))
        .toList();
    return _BoardData(incoming, expected, inHospital, discharged);
  }
}

void _refreshBoard(WidgetRef ref) {
  ref.invalidate(referralsProvider(_incomingKey));
  ref.invalidate(casesProvider(_activeQuery));
  ref.invalidate(casesProvider(_dischargedQuery));
  ref.invalidate(dashboardProvider);
  ref.invalidate(capacityProvider);
  ref.invalidate(alertsProvider);
}

/// The live queue: Incoming → In hospital → Discharged today.
class BoardScreen extends ConsumerStatefulWidget {
  /// Switches the shell to another destination (1 Patients, 2 Hospital, 3 Me).
  final ValueChanged<int> onOpenTab;
  const BoardScreen({super.key, required this.onOpenTab});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  int _lane = 0;

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final data = _BoardData.of(ref);
    final loading = ref.watch(referralsProvider(_incomingKey)).isLoading && data.incoming.isEmpty ||
        ref.watch(casesProvider(_activeQuery)).isLoading && data.inHospital.isEmpty && data.expected.isEmpty;
    final error = ref.watch(referralsProvider(_incomingKey)).error ?? ref.watch(casesProvider(_activeQuery)).error;
    if (isDesk(context)) return _desk(context, data);

    final lanes = [
      'Incoming ${data.incoming.length + data.expected.length}',
      'In hospital ${data.inHospital.length}',
      'Discharged ${data.dischargedToday.length}',
    ];
    return RefreshIndicator(
      color: p.primary,
      onRefresh: () async => _refreshBoard(ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _BoardHeader(onOpenTab: widget.onOpenTab)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CSegmented(labels: lanes, selected: _lane, onChanged: (i) => setState(() => _lane = i)),
            ),
          ),
          if (error != null && data.incoming.isEmpty && data.inHospital.isEmpty)
            SliverToBoxAdapter(child: CError(error: error, onRetry: () => _refreshBoard(ref)))
          else if (loading)
            const SliverToBoxAdapter(child: CLoading())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.list(children: switch (_lane) {
                0 => _incomingLane(data),
                1 => _inHospitalLane(data),
                _ => _dischargedLane(data),
              }),
            ),
        ],
      ),
    );
  }

  List<Widget> _incomingLane(_BoardData d) {
    if (d.incoming.isEmpty && d.expected.isEmpty) {
      return const [
        CEmpty(
          icon: Icons.move_to_inbox_outlined,
          title: 'Nobody on the way',
          message: 'Patients who send their summary from VitaNet appear here instantly.',
        ),
      ];
    }
    return [
      for (final r in d.incoming) ...[IncomingCard(referral: r), const SizedBox(height: 10)],
      if (d.expected.isNotEmpty) ...[
        const Padding(padding: EdgeInsets.fromLTRB(2, 6, 2, 8), child: CSectionLabel('Accepted · on the way')),
        _CaseList(cases: d.expected),
      ],
    ];
  }

  List<Widget> _inHospitalLane(_BoardData d) => d.inHospital.isEmpty
      ? const [CEmpty(icon: Icons.local_hospital_outlined, title: 'No patients in the hospital')]
      : [_CaseList(cases: d.inHospital)];

  List<Widget> _dischargedLane(_BoardData d) => d.dischargedToday.isEmpty
      ? const [CEmpty(icon: Icons.check_circle_outline_rounded, title: 'No discharges yet today')]
      : [_CaseList(cases: d.dischargedToday, discharged: true)];

  Widget _desk(BuildContext context, _BoardData d) {
    final p = ClinicalPalette.of(context);
    final selection = ref.watch(deskSelectionProvider);
    Widget column(String title, int count, List<Widget> children, {int flex = 3}) => Expanded(
          flex: flex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(children: [
                  Text(title.toUpperCase(), style: cText(12, weight: FontWeight.w700, color: p.muted, letterSpacing: 0.7)),
                  const SizedBox(width: 8),
                  Text('$count', style: cMono(12, color: p.ink)),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.only(bottom: 16), children: children),
              ),
            ],
          ),
        );
    return DetailPaneScope(
      child: Column(
        children: [
          _BoardHeader(onOpenTab: widget.onOpenTab, desk: true),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        column('Incoming', d.incoming.length + d.expected.length, [
                          for (final r in d.incoming) ...[
                            IncomingCard(referral: r, compact: true, selected: selection?.id == r.id),
                            const SizedBox(height: 8),
                          ],
                          if (d.expected.isNotEmpty) ...[
                            const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 8), child: CSectionLabel('On the way')),
                            _CaseList(cases: d.expected, selectedId: selection?.id),
                          ],
                          if (d.incoming.isEmpty && d.expected.isEmpty)
                            const CEmpty(icon: Icons.move_to_inbox_outlined, title: 'Nobody on the way'),
                        ], flex: 4),
                        const SizedBox(width: 16),
                        column('In hospital', d.inHospital.length, [
                          if (d.inHospital.isEmpty)
                            const CEmpty(icon: Icons.local_hospital_outlined, title: 'No patients here')
                          else
                            _CaseList(cases: d.inHospital, selectedId: selection?.id),
                        ]),
                        const SizedBox(width: 16),
                        column('Discharged today', d.dischargedToday.length, [
                          if (d.dischargedToday.isEmpty)
                            const CEmpty(icon: Icons.check_circle_outline_rounded, title: 'None yet')
                          else
                            _CaseList(cases: d.dischargedToday, discharged: true, selectedId: selection?.id),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 420,
                  decoration: BoxDecoration(color: p.card, border: Border(left: BorderSide(color: p.line))),
                  child: selection == null
                      ? const CEmpty(
                          icon: Icons.touch_app_outlined,
                          title: 'Select a patient',
                          message: 'Their summary or record opens here.',
                        )
                      : selection.kind == 'referral'
                          ? ReferralView(key: ValueKey(selection.id), referralId: selection.id)
                          : CaseRecordView(key: ValueKey(selection.id), caseId: selection.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title, alerts, duty and accepting switches, bed strip and the latest
/// broadcast. Shared by the phone and desk Board.
class _BoardHeader extends ConsumerWidget {
  final ValueChanged<int> onOpenTab;
  final bool desk;
  const _BoardHeader({required this.onOpenTab, this.desk = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final dash = ref.watch(dashboardProvider).valueOrNull;
    final me = ref.watch(staffAccessProvider).valueOrNull?.me;
    final hospital = ref.watch(myHospitalProvider).valueOrNull;
    final alerts = ref.watch(alertsProvider).valueOrNull ?? const <PortalAlert>[];
    final cap = ref.watch(capacityProvider).valueOrNull;
    final live = ref.watch(portalLiveConnectedProvider);
    final unacked = alerts.where((a) => !a.ackedByMe && a.severity != 'info').length;
    final banner = alerts
        .where((a) => a.kind == 'broadcast' && a.severity != 'info' && DateTime.now().toUtc()
            .difference(DateTime.tryParse(a.at)?.toUtc() ?? DateTime(2000)) < const Duration(hours: 12))
        .firstOrNull;

    final title = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    (hospital?.name ?? 'Your hospital').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cText(12, weight: FontWeight.w600, color: p.muted, letterSpacing: 0.3),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: live ? 'Live updates on' : 'Reconnecting',
                  child: CDot(live ? p.tone(Tone.green).dot : p.faint, size: 7),
                ),
              ]),
              Text('Board', style: cText(desk ? 22 : 26, weight: FontWeight.w700, color: p.ink, letterSpacing: -0.2)),
            ],
          ),
        ),
        CIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Alerts',
          outlined: true,
          badge: unacked,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlertsPage())),
        ),
        if (!desk) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Me',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onOpenTab(3),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.navy, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(initialsOf(me?.fullName ?? ''), style: cText(14, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ],
    );

    final dutyAndAccepting = Row(
      children: [
        Expanded(child: _DutyToggle(onDuty: dash?.onDuty ?? me?.onDuty ?? false)),
        const SizedBox(width: 8),
        _AcceptingChip(accepting: dash?.acceptingReferrals ?? hospital?.acceptingReferrals ?? true, admin: me?.isAdmin ?? false),
      ],
    );

    final strip = cap == null || (cap.wards.isEmpty && cap.equipment.isEmpty)
        ? null
        : SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final w in cap.wards) ...[
                  _StripTile(
                    label: w.name,
                    value: w.bedsFree == 0 ? 'Full' : '${w.bedsFree}',
                    suffix: w.bedsFree == 0 ? '0 / ${w.bedsTotal}' : '/ ${w.bedsTotal} free',
                    tone: w.bedsFree == 0 ? Tone.red : (w.bedsTotal > 0 && w.bedsFree / w.bedsTotal < 0.2 ? Tone.orange : null),
                    onTap: () => onOpenTab(2),
                  ),
                  const SizedBox(width: 8),
                ],
                for (final e in cap.equipment.where((e) => e.total > 0 && e.available / e.total < 0.34)) ...[
                  _StripTile(
                    label: e.name,
                    value: e.available == 0 ? 'None' : '${e.available}',
                    suffix: e.available == 0 ? 'free' : 'left',
                    tone: e.available == 0 ? Tone.red : Tone.orange,
                    onTap: () => onOpenTab(2),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          );

    final bannerWidget = banner == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: p.navy,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlertsPage())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.campaign_outlined, size: 18, color: banner.severity == 'critical' ? const Color(0xFFFCA5A5) : const Color(0xFFFCD98A)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: banner.title, style: cText(13, weight: FontWeight.w700, color: Colors.white)),
                            if ((banner.body ?? '').isNotEmpty) TextSpan(text: ' · ${banner.body}'),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: cText(13, color: Colors.white, height: 1.35),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(clockTime(banner.at), style: cMono(12, color: p.navyMuted)),
                    ],
                  ),
                ),
              ),
            ),
          );

    if (desk) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
        decoration: BoxDecoration(color: p.card, border: Border(bottom: BorderSide(color: p.line))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              SizedBox(width: 420, child: dutyAndAccepting),
            ]),
            if (strip != null || bannerWidget != null) const SizedBox(height: 12),
            if (strip != null) Transform.translate(offset: const Offset(-16, 0), child: strip),
            if (bannerWidget != null) ...[const SizedBox(height: 8), Transform.translate(offset: const Offset(-16, 0), child: bannerWidget)],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child: title),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: dutyAndAccepting),
        if (strip != null) ...[strip, const SizedBox(height: 12)],
        if (bannerWidget != null) ...[bannerWidget, const SizedBox(height: 12)],
      ],
    );
  }
}

class _DutyToggle extends ConsumerStatefulWidget {
  final bool onDuty;
  const _DutyToggle({required this.onDuty});

  @override
  ConsumerState<_DutyToggle> createState() => _DutyToggleState();
}

class _DutyToggleState extends ConsumerState<_DutyToggle> {
  bool? _pending;

  Future<void> _set(bool v) async {
    setState(() => _pending = v);
    final res = await runCAction(context, () => ref.read(hospitalApiProvider).setDuty(v),
        success: v ? "You're on shift." : "You're off shift.");
    if (!mounted) return;
    setState(() => _pending = null);
    if (res != null) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(capacityProvider);
      ref.invalidate(staffAccessProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final on = _pending ?? widget.onDuty;
    return Semantics(
      toggled: on,
      label: on ? 'On shift' : 'Off shift',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _pending != null ? null : () => _set(!on),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                CDot(on ? p.tone(Tone.green).dot : p.faint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(on ? 'On shift' : 'Off shift', style: cText(14, weight: FontWeight.w600, color: p.ink)),
                ),
                IgnorePointer(child: CSwitch(value: on, onChanged: (_) {})),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptingChip extends ConsumerWidget {
  final bool accepting;
  final bool admin;
  const _AcceptingChip({required this.accepting, required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final t = p.tone(accepting ? Tone.green : Tone.orange);
    Future<void> toggle() async {
      final ok = await confirmC(
        context,
        title: accepting ? 'Pause new patients?' : 'Accept new patients again?',
        message: accepting
            ? 'VitaNet will stop sending new patients here and suggest other hospitals. Patients already on the way still come.'
            : 'Patients nearby will be able to send you their summary again.',
        confirm: accepting ? 'Pause' : 'Accept patients',
        danger: accepting,
      );
      if (!ok || !context.mounted) return;
      final res = await runCAction(context, () => ref.read(hospitalApiProvider).setAccepting(!accepting),
          success: accepting ? 'Paused — VitaNet is sending patients elsewhere.' : 'Accepting VitaNet patients.');
      if (res != null) {
        ref.invalidate(dashboardProvider);
        ref.invalidate(myHospitalProvider);
      }
    }

    return Semantics(
      button: admin,
      label: accepting ? 'Accepting new patients' : 'Paused, not accepting new patients',
      excludeSemantics: true,
      child: Material(
        color: t.bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: admin ? toggle : null,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CDot(t.dot, size: 8),
                const SizedBox(width: 6),
                Text(accepting ? 'Accepting' : 'Paused', style: cText(13, weight: FontWeight.w600, color: t.fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StripTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Tone? tone;
  final VoidCallback onTap;
  const _StripTile({required this.label, required this.value, required this.suffix, this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final t = tone == null ? null : p.tone(tone!);
    return Material(
      color: t?.bg ?? p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: t?.border ?? p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label.toUpperCase(), style: cText(11, weight: FontWeight.w600, color: t?.fg ?? p.muted)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: value, style: cMono(15, color: t?.fg ?? p.ink)),
                  TextSpan(text: ' $suffix', style: cText(12, color: t?.fg ?? p.muted)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An incoming patient: level, ETA countdown, who, complaint, allergy,
/// with Decline / Accept right on the card.
class IncomingCard extends ConsumerWidget {
  final Referral referral;
  final bool compact;
  final bool selected;
  const IncomingCard({super.key, required this.referral, this.compact = false, this.selected = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final r = referral;
    final s = r.summary;
    final who = ageSex(s.age, s.sex);
    final shared = [
      if (s.vitals.isNotEmpty) 'Vitals',
      if (s.medications.isNotEmpty || s.conditions.isNotEmpty) 'History',
    ];
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? p.primary : p.line, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => openReferral(context, ref, r.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Semantics(
                label: '${levelLabel(r.triageLevel)}: ${r.patientName}, ${s.complaint ?? ''}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              LevelChip(r.triageLevel),
                              if (r.source == 'checkin') const CChip('Check-in', tone: Tone.blue),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('ETA ', style: cText(12, color: p.muted)),
                        Every(builder: (_) => Text(etaText(r.minutesToArrival()), style: cMono(compact ? 15 : 20, color: p.ink))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: r.patientName),
                        if (who.isNotEmpty) TextSpan(text: ' · $who', style: cText(16, weight: FontWeight.w500, color: p.muted)),
                      ]),
                      style: cText(16, weight: FontWeight.w600, color: p.ink),
                    ),
                    Text(s.complaint ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: cText(14, color: p.body)),
                    if (s.allergies.isNotEmpty || shared.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (s.allergies.isNotEmpty) CChip('Allergy · ${s.allergies.join(', ')}', tone: Tone.red, bordered: true),
                        if (shared.isNotEmpty && !compact) CChip('${shared.join(' & ')} shared'),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  flex: compact ? 2 : 1,
                  child: CButton('Decline',
                      kind: CButtonKind.secondary,
                      height: compact ? 40 : 44,
                      fontSize: compact ? 14 : 15,
                      onPressed: () => showDeclineSheet(context, ref, r)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: compact ? 3 : 2,
                  child: CButton('Accept',
                      height: compact ? 40 : 44, fontSize: compact ? 14 : 15, onPressed: () => showAcceptSheet(context, ref, r)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact rows of patients in one card.
class _CaseList extends ConsumerWidget {
  final List<PortalCase> cases;
  final bool discharged;
  final String? selectedId;
  const _CaseList({required this.cases, this.discharged = false, this.selectedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    return CCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < cases.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.divider),
            CaseRow(portalCase: cases[i], discharged: discharged, selected: cases[i].id == selectedId),
          ],
        ],
      ),
    );
  }
}

class CaseRow extends ConsumerWidget {
  final PortalCase portalCase;
  final bool discharged;
  final bool selected;
  final bool showRef;
  const CaseRow({super.key, required this.portalCase, this.discharged = false, this.selected = false, this.showRef = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final c = portalCase;
    final where = [c.wardName, c.bed].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final ews = c.latestVitals?.earlyWarning;
    final subtitle = discharged
        ? '${outcomeLabel(c.outcome)} · ${clockTime(c.updatedAt)}'
        : [
            if (showRef) caseRef(c.id),
            if (where.isNotEmpty) where else if (!c.isExpected) 'Waiting area',
            caseStatusLabel(c.status), // "On the way" / "Waiting" / "In treatment"
          ].join(' · ');
    return Material(
      color: selected ? p.primaryTint : Colors.transparent,
      child: InkWell(
        onTap: () => openCase(context, ref, c.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: LayoutBuilder(builder: (context, constraints) {
            // In a narrow desk column the name matters more than the timer
            // and the assignee avatar; both are on the record anyway.
            final narrow = constraints.maxWidth < 380;
            final tight = constraints.maxWidth < 320;
            return Row(
              children: [
                CDot(discharged ? p.faint : p.tone(levelTone(c.level)).dot),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: c.patientName),
                          if (ageSex(c.age, c.sex).isNotEmpty)
                            TextSpan(text: ' · ${ageSex(c.age, c.sex)}', style: cText(15, weight: FontWeight.w500, color: p.muted)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: cText(15, weight: FontWeight.w600, color: p.ink),
                      ),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: cText(13, color: p.muted)),
                    ],
                  ),
                ),
                if (ews != null && ews >= 5 && !discharged) ...[
                  CChip('EWS $ews', tone: earlyWarningTone(ews)),
                  const SizedBox(width: 8),
                ],
                if (c.isExpected)
                  _ArrivedButton(portalCase: c)
                else if (!discharged) ...[
                  if (!narrow) ...[
                    Every(builder: (_) => Text(elapsed(c.arrivedAt ?? c.createdAt), style: cMono(13, weight: FontWeight.w500, color: p.body))),
                    const SizedBox(width: 8),
                  ],
                  if (!tight) CAvatar(c.assigneeName ?? '', size: 30),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ArrivedButton extends ConsumerStatefulWidget {
  final PortalCase portalCase;
  const _ArrivedButton({required this.portalCase});

  @override
  ConsumerState<_ArrivedButton> createState() => _ArrivedButtonState();
}

class _ArrivedButtonState extends ConsumerState<_ArrivedButton> {
  bool _saving = false;

  Future<void> _arrive() async {
    setState(() => _saving = true);
    final res = await runCAction(context, () => ref.read(hospitalApiProvider).markArrived(widget.portalCase.id),
        success: '${widget.portalCase.patientName} has arrived.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      ref.invalidate(casesProvider);
      ref.invalidate(caseProvider(widget.portalCase.id));
    }
  }

  @override
  Widget build(BuildContext context) =>
      CButton('Arrived', kind: CButtonKind.tint, expand: false, height: 36, fontSize: 13, loading: _saving, onPressed: _arrive);
}
