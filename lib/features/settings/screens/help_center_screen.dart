import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const _faqs = <(String, String)>[
    (
      'Is VitaNet a replacement for a doctor?',
      'No. VitaNet helps you decide how urgently to seek care and what to tell a clinician. It cannot diagnose. In an emergency, always call 112.'
    ),
    (
      'How accurate is the AI triage?',
      'Triage is based on clinical guidelines and checked against your vitals. It errs on the side of caution, so it may recommend a doctor more often than strictly needed.'
    ),
    (
      'Who can see my health data?',
      'Only you, and the care circle contacts you choose. Data is encrypted and never sold or used to train AI models.'
    ),
    (
      'How do I connect my smartwatch?',
      'On Home, tap any vital card marked Pair. VitaNet works with Health Connect on Android and Apple Health on iPhone.'
    ),
    (
      'Can I share a result with my doctor?',
      'Yes. Open a triage result and tap Share, or export a summary of your profile and past checks from Settings, Privacy & data.'
    ),
    (
      'How do I delete my data?',
      'Settings, then Privacy & data, then Clear triage history removes past checks. To close your account entirely, email support and it is erased within 30 days.'
    ),
  ];

  int _open = -1;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final q = _query.trim().toLowerCase();
    final faqs = [
      for (var i = 0; i < _faqs.length; i++)
        if (q.isEmpty ||
            _faqs[i].$1.toLowerCase().contains(q) ||
            _faqs[i].$2.toLowerCase().contains(q))
          i,
    ];

    Widget quick(IconData icon, Color bg, Color fg, String label, VoidCallback onTap) => Expanded(
          child: VnCard(
            radius: 18,
            onTap: onTap,
            semanticLabel: label,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            child: Column(
              children: [
                VnIconTile(icon: icon, bg: bg, fg: fg, size: 42, radius: 14),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
              ],
            ),
          ),
        );

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                const VnTopBar(title: 'Help center'),
                const SizedBox(height: 18),
                VnTextField(
                  hint: 'How can we help?',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    quick(Icons.chat_bubble_outline_rounded, const Color(0xFFCCFBF1),
                        const Color(0xFF0F766E), 'Live chat', () => context.go('/chat')),
                    const SizedBox(width: 10),
                    quick(Icons.mail_outline_rounded, const Color(0xFFE0F2FE),
                        const Color(0xFF0369A1), 'Email us',
                        () => LaunchHelpers.openUrlOrSnack(context, 'mailto:support@vitanet.health')),
                    const SizedBox(width: 10),
                    quick(Icons.play_arrow_outlined, const Color(0xFFF5F3FF),
                        const Color(0xFF6D28D9), 'Video guides', () => context.push('/resources/videos')),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Common questions',
                    style: VnText.heading(17, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 18),
                if (faqs.isEmpty)
                  Text('No answers match "$_query". Try Live chat or email us.',
                      style: VnText.body(14, color: p.muted)),
                for (final i in faqs) ...[
                  _FaqTile(
                    q: _faqs[i].$1,
                    a: _faqs[i].$2,
                    open: _open == i,
                    onTap: () => setState(() => _open = _open == i ? -1 : i),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 18),
                Text('Support hours: Mon–Sat, 8:00–20:00 WAT',
                    textAlign: TextAlign.center, style: VnText.body(13, color: p.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;
  final bool open;
  final VoidCallback onTap;
  const _FaqTile({required this.q, required this.a, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(q,
                            style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more_rounded, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(a, style: VnText.body(14, color: p.inkSoft, height: 1.6)),
              ),
          ],
        ),
      ),
    );
  }
}
