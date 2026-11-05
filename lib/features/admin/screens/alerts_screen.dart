import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/referrals_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Real alerts only: new urgent referrals and vitals alerts from patients
/// with an open referral here (GET /portal/alerts).
class AlertsScreen extends ConsumerWidget {
  final bool active;
  const AlertsScreen({super.key, this.active = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(alertsProvider);
    return AutoRefresh(
      active: active,
      onTick: () => ref.invalidate(alertsProvider),
      child: Column(
        children: [
          PortalHeader(
            title: 'Alerts',
            subtitle: 'Urgent referrals, vitals alerts & operational broadcasts',
            trailing: StaffIconButton(
              icon: Icons.add_alert_rounded,
              tooltip: 'Broadcast operational alert',
              background: const Color(0x1F2DD4BF),
              foreground: AppColors.mintLight,
              onPressed: () async {
                final created = await showStaffSheet<bool>(
                  context,
                  tall: true,
                  builder: (_) => const BroadcastAlertSheet(),
                );
                if (created == true) ref.invalidate(alertsProvider);
              },
            ),
          ),
          Expanded(
            child: PortalAsyncList<List<PortalAlert>>(
              value: value,
              onRefresh: () => ref.refresh(alertsProvider.future),
              builder: (list) => list.isEmpty
                  ? const [
                      PortalEmpty(
                        icon: Icons.notifications_none_rounded,
                        title: 'No alerts right now',
                        message: 'Urgent referrals and vitals alerts from patients heading here will show up here.',
                      ),
                    ]
                  : [
                      for (final a in list) ...[
                        AlertCard(
                          alert: a,
                          onTap: a.referralId == null ? null : () => openReferral(context, a.referralId!),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final PortalAlert alert;
  final VoidCallback? onTap;
  const AlertCard({super.key, required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final critical = alert.severity == 'critical';
    final t = p.tone(critical ? StaffTone.danger : StaffTone.amber);
    final icon = switch (alert.kind) {
      'referral' => Icons.move_to_inbox_outlined,
      'vitals' => Icons.monitor_heart_outlined,
      'broadcast' => Icons.campaign_rounded,
      _ => Icons.notifications_active_outlined,
    };
    return StaffTap(
      onTap: onTap,
      color: p.card,
      radius: 16,
      semanticLabel: '${critical ? 'Critical' : 'Warning'}: ${alert.title}',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: p.dark ? t.fg : t.strong),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alert.title, style: staffBody(15, weight: FontWeight.w700, color: p.ink)),
                      ),
                      if (alert.department != null && alert.department!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.chip,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(alert.department!, style: staffBody(10, weight: FontWeight.bold, color: p.muted)),
                        ),
                    ],
                  ),
                  if ((alert.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(alert.body!, style: staffBody(13, color: p.body)),
                  ],
                  const SizedBox(height: 4),
                  Text(relativeTime(alert.at), style: staffBody(12, color: p.muted)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.faint),
          ],
        ),
      ),
    );
  }
}

/// Sheet for clinical staff to broadcast operational alerts.
class BroadcastAlertSheet extends ConsumerStatefulWidget {
  const BroadcastAlertSheet({super.key});

  @override
  ConsumerState<BroadcastAlertSheet> createState() => _BroadcastAlertSheetState();
}

class _BroadcastAlertSheetState extends ConsumerState<BroadcastAlertSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  String _severity = 'warning';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      showStaffSnack(context, 'Provide both an alert title and details.');
      return;
    }

    setState(() => _saving = true);
    final r = await runPortalAction(
      context,
      () => ref.read(hospitalApiProvider).createBroadcastAlert(
            title: title,
            body: body,
            severity: _severity,
            department: _deptCtrl.text.trim(),
          ),
      success: 'Broadcast alert published.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PortalSheet(
      title: 'Broadcast Facility Alert',
      subtitle: 'Post an operational notice or priority clinical alert across the department.',
      actions: [
        StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Broadcast', loading: _saving, onPressed: _submit),
      ],
      children: [
        PortalTextField(
          controller: _titleCtrl,
          label: 'Alert Headline',
          hint: 'e.g. Trauma Bay 2 reserved for inbound MVA',
        ),
        const SizedBox(height: 12),
        PortalTextField(
          controller: _deptCtrl,
          label: 'Department (optional)',
          hint: 'ER, ICU, Surgery, Pharmacy, General',
        ),
        const SizedBox(height: 12),
        PortalTextField(
          controller: _bodyCtrl,
          label: 'Alert Body / Instructions',
          hint: 'Details, required staff prep, or operational notice…',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Priority Warning'),
                selected: _severity == 'warning',
                onSelected: (_) => setState(() => _severity = 'warning'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('Critical Emergency'),
                selected: _severity == 'critical',
                onSelected: (_) => setState(() => _severity = 'critical'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
