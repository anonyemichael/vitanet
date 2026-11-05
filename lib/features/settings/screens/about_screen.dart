import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);

    Widget stat(String value, String label) => Expanded(
          child: VnCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              children: [
                Text(value, style: VnText.body(18, weight: FontWeight.w800, color: p.brand)),
                const SizedBox(height: 4),
                Text(label,
                    textAlign: TextAlign.center,
                    style: VnText.body(11, weight: FontWeight.w600, color: p.muted)),
              ],
            ),
          ),
        );

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                const VnTopBar(title: 'About'),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 6),
                  child: Column(
                    children: [
                      const VitaNetLogo(size: 96, glow: true),
                      const SizedBox(height: 10),
                      Text('VitaNet', style: VnText.heading(26, color: p.ink)),
                      const SizedBox(height: 10),
                      Text('Version 1.0.0 · Up to date',
                          style: VnText.body(14, color: p.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'VitaNet helps people decide when and where to get care. It combines a clinically guided AI assistant with your live vitals, so the advice fits you, not an average patient.',
                  textAlign: TextAlign.center,
                  style: VnText.body(15, color: p.inkSoft, height: 1.65),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    stat('377', 'Symptoms modelled'),
                    const SizedBox(width: 10),
                    stat('4', 'Triage levels'),
                    const SizedBox(width: 10),
                    stat('24/7', 'Availability'),
                  ],
                ),
                const SizedBox(height: 20),
                VnListGroup(children: [
                  VnListRow(title: 'Medical disclaimer', onTap: () => context.push('/disclaimer')),
                  VnListRow(title: 'Privacy policy', onTap: () => context.push('/privacy')),
                  VnListRow(
                    title: 'Open-source licences',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'VitaNet',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: VitaNetLogo(size: 48),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 28),
                Text('Built with clinicians in Lagos and Accra.\n© 2026 VitaNet Health',
                    textAlign: TextAlign.center,
                    style: VnText.body(12, color: p.muted, height: 1.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
