import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/app/router.dart';
import 'package:vitanet/data/models/health_alert.dart';
import 'package:vitanet/data/providers/health_alerts_provider.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Puts the newest unanswered health alert on top of every screen.
///
/// "I'm OK" answers it (an urgent alert nobody answers is sent to the care
/// circle after 10 minutes). "Find hospital" opens the hospital list, and an
/// urgent alert also offers "Call 112".
class HealthAlertOverlay extends ConsumerWidget {
  const HealthAlertOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(activeHealthAlertProvider);
    return Stack(
      children: [
        child,
        if (alert != null)
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: HealthAlertCard(alert: alert),
              ),
            ),
          ),
      ],
    );
  }
}

class HealthAlertCard extends ConsumerWidget {
  const HealthAlertCard({super.key, required this.alert});

  final HealthAlertItem alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final urgent = alert.isUrgent;
    final fg = urgent ? const Color(0xFFBE123C) : const Color(0xFFB45309);
    final bg = urgent ? const Color(0xFFFFE4E6) : const Color(0xFFFEF3C7);
    final escalated = alert.status == 'escalated';
    return Semantics(
      liveRegion: true,
      label: urgent ? 'Urgent health alert' : 'Health alert',
      child: Material(
        elevation: 6,
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fg.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(urgent ? Icons.warning_amber_rounded : Icons.monitor_heart_outlined,
                        color: fg, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(urgent ? 'Urgent health alert' : 'Health alert',
                        style: VnText.heading(15, color: fg)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(alert.message, style: VnText.body(13.5, color: p.ink)),
              if (escalated) ...[
                const SizedBox(height: 6),
                Text('Your care circle has been told.',
                    style: VnText.body(12.5, weight: FontWeight.w700, color: p.muted)),
              ],
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () => ref.read(goRouterProvider).push('/hospitals'),
                    child: const Text('Find hospital'),
                  ),
                  if (urgent)
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.parse('tel:112');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      child: Text('Call 112', style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                    ),
                  FilledButton(
                    onPressed: () => ref.read(healthAlertsProvider.notifier).acknowledge(alert.id),
                    child: const Text("I'm OK"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
