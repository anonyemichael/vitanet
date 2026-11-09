import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/board/referral_view.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/record/case_record_view.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: ClinicalPalette.of(context).bg,
        body: const SafeArea(child: AlertsView()),
      );
}

/// Urgent incoming patients, watch alerts from patients heading here, early
/// warning scores and staff broadcasts — with "I'm on it" so the team can see
/// who picked each one up.
class AlertsView extends ConsumerStatefulWidget {
  const AlertsView({super.key});

  @override
  ConsumerState<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends ConsumerState<AlertsView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final value = ref.watch(alertsProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
              child: Row(
                children: [
                  CIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
                  Expanded(child: Text('Alerts', style: cText(22, weight: FontWeight.w700, color: p.ink))),
                  CButton('Broadcast',
                      kind: CButtonKind.secondary,
                      icon: Icons.campaign_outlined,
                      expand: false,
                      height: 40,
                      fontSize: 14,
                      onPressed: () async {
                        final sent = await showCSheet<bool>(context, builder: (_) => const BroadcastSheet());
                        if (sent == true) ref.invalidate(alertsProvider);
                      }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CSegmented(
                labels: const ['Needs attention', 'All'],
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: p.primary,
                onRefresh: () => ref.refresh(alertsProvider.future),
                child: value.when(
                  loading: () => ListView(children: const [CLoading()]),
                  error: (e, _) => ListView(children: [CError(error: e, onRetry: () => ref.invalidate(alertsProvider))]),
                  data: (all) {
                    final list = _tab == 0 ? all.where((a) => !a.ackedByMe && a.severity != 'info').toList() : all;
                    if (list.isEmpty) {
                      return ListView(children: [
                        CEmpty(
                          icon: Icons.notifications_none_rounded,
                          title: _tab == 0 ? "You're all caught up" : 'No alerts right now',
                          message: 'Urgent incoming patients, early warning scores and broadcasts show up here.',
                        ),
                      ]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => AlertCard(alert: list[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertCard extends ConsumerStatefulWidget {
  final PortalAlert alert;
  const AlertCard({super.key, required this.alert});

  @override
  ConsumerState<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends ConsumerState<AlertCard> {
  bool _saving = false;

  Future<void> _ack() async {
    setState(() => _saving = true);
    final res = await runCAction(context, () => ref.read(hospitalApiProvider).ackAlert(widget.alert.id));
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) ref.invalidate(alertsProvider);
  }

  void _open() {
    final a = widget.alert;
    final page = a.caseId != null
        ? CaseRecordPage(caseId: a.caseId!)
        : a.referralId != null
            ? ReferralPage(referralId: a.referralId!)
            : null;
    if (page != null) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final a = widget.alert;
    final (String kind, Tone tone) = switch (a.kind) {
      'broadcast' => ('BROADCAST', a.severity == 'critical' ? Tone.red : Tone.blue),
      'referral' => ('INCOMING', Tone.red),
      'early_warning' => ('EARLY WARNING', a.severity == 'critical' ? Tone.red : Tone.orange),
      _ => ('VITALS', a.severity == 'critical' ? Tone.red : Tone.orange),
    };
    final seen = a.ackedByMe
        ? (a.ackCount > 1 ? 'You and ${a.ackCount - 1} other${a.ackCount == 2 ? '' : 's'} are on it' : "You're on it")
        : a.ackCount == 0
            ? 'Nobody has picked this up'
            : '${a.ackNames.take(2).join(', ')}${a.ackCount > 2 ? ' +${a.ackCount - 2}' : ''} on it';
    final canOpen = a.caseId != null || a.referralId != null;
    return CCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CChip(kind, tone: tone, height: 22),
              if ((a.department ?? '').isNotEmpty) ...[const SizedBox(width: 6), CChip(a.department!, height: 22)],
              const Spacer(),
              Text(clockTime(a.at), style: cMono(12, weight: FontWeight.w500, color: p.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.title, style: cText(15, weight: FontWeight.w600, color: p.ink)),
          if ((a.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(a.body!, style: cText(14, color: p.body, height: 1.45)),
          ],
          if (a.kind == 'broadcast' && (a.authorName ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('From ${a.authorName}', style: cText(12, color: p.muted))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(seen, style: cText(12, color: p.muted))),
              if (canOpen) ...[
                CButton('Open', kind: CButtonKind.secondary, expand: false, height: 36, fontSize: 13, onPressed: _open),
                const SizedBox(width: 8),
              ],
              if (!a.ackedByMe)
                CButton("I'm on it", kind: CButtonKind.dark, expand: false, height: 36, fontSize: 13, loading: _saving, onPressed: _ack),
            ],
          ),
        ],
      ),
    );
  }
}

class BroadcastSheet extends ConsumerStatefulWidget {
  const BroadcastSheet({super.key});

  @override
  ConsumerState<BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends ConsumerState<BroadcastSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _dept = TextEditingController();
  int _severity = 0; // warning, critical, info
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _dept.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().length < 3 || _body.text.trim().length < 5) {
      showCSnack(context, 'Add a headline and a few words of detail.');
      return;
    }
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => ref.read(hospitalApiProvider).createBroadcastAlert(
            title: _title.text.trim(),
            body: _body.text.trim(),
            severity: const ['warning', 'critical', 'info'][_severity],
            department: _dept.text.trim(),
          ),
      success: 'Sent to everyone at your hospital.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => CSheet(
        title: 'Broadcast an alert',
        subtitle: 'Everyone on staff at your hospital sees it on the Board and in Alerts.',
        gap: 14,
        actions: [
          CButton('Cancel', kind: CButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
          CButton('Broadcast', loading: _saving, onPressed: _send),
        ],
        children: [
          CTextField(controller: _title, label: 'Headline', hint: 'e.g. Trauma bay 2 reserved'),
          CTextField(controller: _body, label: 'Details', hint: 'What staff need to know or prepare', maxLines: 3),
          CTextField(controller: _dept, label: 'Department (optional)', hint: 'e.g. Emergency'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CSectionLabel('How serious'),
              const SizedBox(height: 8),
              CSegmented(labels: const ['Warning', 'Critical', 'Info'], selected: _severity, onChanged: (i) => setState(() => _severity = i)),
            ],
          ),
        ],
      );
}
