import 'package:flutter/material.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String, IconData)>[
    (
      'What we collect',
      'Your profile, the symptoms you describe, files you upload, and vitals from devices you connect. Nothing from your phone is read without permission.',
      Icons.description_outlined
    ),
    (
      'How we use it',
      'Only to give you triage advice, reminders and insights. Anonymised, aggregated statistics may improve our clinical guidelines.',
      Icons.auto_awesome_outlined
    ),
    (
      'Who sees it',
      'You, plus care circle contacts you approve. Urgent alerts share your location only at the moment they are sent.',
      Icons.group_outlined
    ),
    (
      'How it is protected',
      'Encryption at rest and in transit, with access limited to the services that need it.',
      Icons.lock_outline_rounded
    ),
    (
      'Your rights',
      'Export your data or clear your history at any time from Settings. Account deletion completes within 30 days of your request.',
      Icons.check_rounded
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                const VnTopBar(title: 'Privacy policy'),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.brandWash,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.brandBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: p.brand,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.shield_outlined, color: p.onBrand),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('The short version',
                                style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                            const SizedBox(height: 4),
                            Text(
                              'Your health data is yours. We encrypt it, never sell it, and never use it to train AI models.',
                              style: VnText.body(13,
                                  color: p.isDark ? p.brandDeep : const Color(0xFF134E4A),
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Last updated 1 October 2026 · HIPAA and GDPR aligned',
                    style: VnText.body(12, color: p.muted)),
                for (final (title, body, icon) in _sections) ...[
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.line),
                        ),
                        child: Icon(icon, size: 18, color: p.brand),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(title,
                                  style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
                            ),
                            const SizedBox(height: 6),
                            Text(body, style: VnText.body(14, color: p.inkSoft, height: 1.6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                VnOutlineButton(
                  label: 'Contact our data protection officer',
                  icon: Icons.mail_outline_rounded,
                  borderColor: p.brand,
                  foreground: p.brand,
                  onPressed: () =>
                      LaunchHelpers.openUrlOrSnack(context, 'mailto:privacy@vitanet.health'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
