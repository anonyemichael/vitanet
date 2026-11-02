import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          const PortalHeader(title: 'Alerts', subtitle: 'Urgent referrals and vitals from consenting patients'),
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
              child: Icon(alert.kind == 'referral' ? Icons.move_to_inbox_outlined : Icons.monitor_heart_outlined,
                  size: 20, color: p.dark ? t.fg : t.strong),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: staffBody(15, weight: FontWeight.w700, color: p.ink)),
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
