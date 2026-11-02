import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/notifications/screens/notifications_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// "AI health insights" horizontal card rail.
///
/// Insights are personalised from the profile (medications, conditions) and
/// the latest triage result where available.
class AiHealthAlertsSection extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry? padding;
  const AiHealthAlertsSection({super.key, this.padding});

  @override
  ConsumerState<AiHealthAlertsSection> createState() =>
      _AiHealthAlertsSectionState();
}

class _AiHealthAlertsSectionState extends ConsumerState<AiHealthAlertsSection> {
  bool _doseLogged = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final history = ref.watch(triageHistoryProvider);
    final meds = profile?.medications ?? const <String>[];
    final conditions = profile?.preExistingConditions ?? const <String>[];

    final insights = <_Insight>[
      _Insight(
        icon: Icons.show_chart_rounded,
        color: const Color(0xFFB45309),
        title: conditions.any((c) => c.toLowerCase().contains('hypert'))
            ? 'Blood pressure trend'
            : 'Heart rate trend',
        body: conditions.any((c) => c.toLowerCase().contains('hypert'))
            ? 'Track your evening readings this week. A steady rise is worth raising with your doctor.'
            : 'Your resting heart rate is a good early signal of stress, illness or poor sleep. Check how it has moved this week.',
        action: 'View insights',
        onTap: () => context.push('/health-trends/heart_rate'),
      ),
      _Insight(
        icon: Icons.medication_outlined,
        color: const Color(0xFF6D28D9),
        title: 'Medication reminder',
        body: meds.isNotEmpty
            ? '${meds.first} is on your list. ${_doseLogged ? "Today's dose is logged." : "You haven't logged today's dose."}'
            : 'Add your medicines so VitaNet can remind you and check for interactions.',
        action: meds.isNotEmpty ? (_doseLogged ? 'Logged' : 'Log dose') : 'Add medicines',
        onTap: meds.isNotEmpty
            ? (_doseLogged
                ? null
                : () {
                    setState(() => _doseLogged = true);
                    context.showSnack('Dose logged for today');
                  })
            : () => context.push('/edit-profile', extra: 'medical'),
      ),
      if (history.isNotEmpty)
        _Insight(
          icon: Icons.history_rounded,
          color: const Color(0xFF0F766E),
          title: 'Last check',
          body: history.first.summary.isNotEmpty
              ? history.first.summary
              : 'Review the advice from your most recent symptom check.',
          action: 'View history',
          onTap: () => context.push('/history'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VnSectionHeader(
          title: 'AI health insights',
          action: 'See all',
          onAction: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: LayoutBuilder(builder: (context, box) => OverflowBox(
            maxWidth: box.maxWidth + 40,
            minWidth: box.maxWidth + 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              itemCount: insights.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(width: 260, child: _InsightCard(insights[i])),
            ),
          )),
        ),
      ],
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String action;
  final VoidCallback? onTap;

  const _Insight({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.action,
    this.onTap,
  });
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  const _InsightCard(this.insight);

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final c = p.tintFg(insight.color);
    return VnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.icon, size: 16, color: c),
              const SizedBox(width: 8),
              Expanded(
                child: Text(insight.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VnText.body(12, weight: FontWeight.w700, color: c)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(insight.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: VnText.body(14, color: p.ink, height: 1.45)),
          ),
          VnLink(
            label: insight.action,
            weight: FontWeight.w700,
            color: insight.onTap == null ? p.muted : null,
            onTap: insight.onTap,
          ),
        ],
      ),
    );
  }
}
