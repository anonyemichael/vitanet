import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitanet/core/constants/app_strings.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';
import 'package:vitanet/features/triage_result/widgets/referral_section.dart';

/// Per-level hero palette and copy (AA contrast with white text).
class _LevelSpec {
  final Color hero;
  final Color soft; // body text on hero
  final String badge;
  final String headline;
  final IconData icon;
  final int index;

  const _LevelSpec(this.hero, this.soft, this.badge, this.headline, this.icon, this.index);

  static _LevelSpec of(TriageLevel l) => switch (l) {
        TriageLevel.selfCare => const _LevelSpec(Color(0xFF047857), Color(0xFFD1FAE5),
            'SELF-CARE · LEVEL 1 OF 4', 'You can look after this at home', Icons.home_outlined, 0),
        TriageLevel.pharmacist => const _LevelSpec(Color(0xFFB45309), Color(0xFFFEF3C7),
            'PHARMACIST · LEVEL 2 OF 4', 'Speak to a pharmacist today', Icons.local_pharmacy_outlined, 1),
        TriageLevel.doctor => const _LevelSpec(Color(0xFFC2410C), Color(0xFFFFEDD5),
            'DOCTOR · LEVEL 3 OF 4', 'Book a doctor within 24 hours', Icons.medical_services_outlined, 2),
        TriageLevel.emergency => const _LevelSpec(Color(0xFFB91C1C), Color(0xFFFEE2E2),
            'URGENT · LEVEL 4 OF 4', 'Go to an emergency department now', Icons.local_hospital_outlined, 3),
      };
}

/// Displays the AI triage recommendation after a chat session.
class TriageResultScreen extends ConsumerWidget {
  final bool isEmbedded;
  const TriageResultScreen({super.key, this.isEmbedded = false});

  void _share(TriageResult r, _LevelSpec spec) {
    Share.share(
      'VitaNet triage result\n\n'
          'Level: ${spec.headline}\n'
          'Symptom: ${r.primarySymptom}\n'
          '${r.summary}\n\n'
          'Recommendations:\n'
          '${r.recommendations.map((x) => '- $x').join('\n')}\n\n'
          '${AppStrings.disclaimer}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final result = ref.watch(triageResultProvider);

    if (result == null) {
      return Scaffold(
        backgroundColor: p.page,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              children: [
                if (!isEmbedded) VnTopBar(title: 'Triage result', onBack: () => context.go('/home')),
                const Spacer(),
                const VnIconTile(
                  icon: Icons.assignment_outlined,
                  bg: Color(0xFFCCFBF1),
                  fg: Color(0xFF0F766E),
                  size: 64,
                  radius: 20,
                  iconSize: 30,
                ),
                const SizedBox(height: 16),
                Text('No result yet', style: VnText.heading(20, color: p.ink)),
                const SizedBox(height: 6),
                Text('Start a symptom check to get a triage recommendation.',
                    textAlign: TextAlign.center,
                    style: VnText.body(14, color: p.muted)),
                const SizedBox(height: 22),
                VnButton(label: 'Start a check', onPressed: () => context.go('/chat')),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    final spec = _LevelSpec.of(result.level);
    final contacts = ref.watch(userProfileProvider)?.emergencyContacts ?? const [];
    final callable = contacts.where((c) => c.phone.trim().isNotEmpty).toList();
    final t = result.timestamp;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final isToday = DateUtils.isSameDay(t, DateTime.now());

    final facility = switch (result.level) {
      TriageLevel.emergency => ('Nearest emergency care', 'Hospitals and A&E near you'),
      TriageLevel.doctor => ('Clinics near you', 'Book or walk in today'),
      TriageLevel.pharmacist => ('Pharmacies near you', 'Open now, with distance'),
      TriageLevel.selfCare => ('Pharmacies near you', 'For over-the-counter relief'),
    };

    Widget heroIconButton(IconData icon, String tip, VoidCallback onTap) => VnIconButton(
          icon: icon,
          tooltip: tip,
          background: Colors.white.withValues(alpha: 0.14),
          foreground: Colors.white,
          onPressed: onTap,
        );

    const levelNames = ['Self-care', 'Pharmacist', 'Doctor', 'Emergency'];
    const levelBars = [Color(0xFF6EE7B7), Color(0xFFFCD34D), Color(0xFFFDBA74), Color(0xFFFCA5A5)];

    return Scaffold(
      backgroundColor: p.page,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero ──
            Container(
              color: spec.hero,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            if (!isEmbedded)
                              heroIconButton(Icons.chevron_left_rounded, 'Back', () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  ref.read(chatMessagesProvider.notifier).clear();
                                  context.go('/home');
                                }
                              })
                            else
                              const SizedBox(width: 44),
                            Expanded(
                              child: Text('Triage result',
                                  textAlign: TextAlign.center,
                                  style: VnText.heading(16,
                                      weight: FontWeight.w700, color: Colors.white)),
                            ),
                            heroIconButton(Icons.ios_share_rounded, 'Share result',
                                () => _share(result, spec)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(spec.badge,
                            style: VnText.body(12,
                                weight: FontWeight.w800, letterSpacing: 0.6, color: spec.hero)),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(spec.headline,
                            style: VnText.heading(28, color: Colors.white, height: 1.2)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        result.summary.isNotEmpty
                            ? result.summary
                            : 'Based on ${result.primarySymptom} reported at $hh:$mm${isToday ? ' today' : ''}.',
                        style: VnText.body(15, color: spec.soft, height: 1.5),
                      ),
                      if (result.summary.isNotEmpty && result.primarySymptom.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Main symptom: ${result.primarySymptom} · $hh:$mm${isToday ? ' today' : ''}',
                          style: VnText.body(13, color: spec.soft.withValues(alpha: 0.85)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Semantics(
                        label: 'Level ${spec.index + 1} of 4, ${levelNames[spec.index]}',
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  for (var i = 0; i < 4; i++) ...[
                                    if (i > 0) const SizedBox(width: 4),
                                    Expanded(
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: i == spec.index
                                              ? Colors.white
                                              : levelBars[i].withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  for (var i = 0; i < 4; i++)
                                    Expanded(
                                      child: Text(levelNames[i],
                                          style: VnText.body(11,
                                              weight: i == spec.index
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: i == spec.index
                                                  ? Colors.white
                                                  : spec.soft.withValues(alpha: 0.85))),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ──
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.level == TriageLevel.emergency) ...[
                        VnButton(
                          label: 'Call emergency services',
                          icon: Icons.call_rounded,
                          height: 58,
                          background: const Color(0xFFB91C1C),
                          foreground: Colors.white,
                          onPressed: () => LaunchHelpers.dialOrSnack(context, '112'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      VnCard(
                        onTap: () => context.push('/pharmacy'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            VnIconTile(
                              icon: result.level == TriageLevel.emergency
                                  ? Icons.local_hospital_outlined
                                  : Icons.local_pharmacy_outlined,
                              bg: const Color(0xFFFEE2E2),
                              fg: const Color(0xFFB91C1C),
                              size: 46,
                              radius: 14,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(facility.$1,
                                      style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                                  const SizedBox(height: 2),
                                  Text(facility.$2, style: VnText.body(13, color: p.muted)),
                                ],
                              ),
                            ),
                            Text('Directions',
                                style: VnText.body(13, weight: FontWeight.w700, color: p.brand)),
                          ],
                        ),
                      ),
                      if (result.level != TriageLevel.selfCare) ...[
                        const SizedBox(height: 16),
                        ReferralSection(result: result),
                      ],
                      if (result.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        VnCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recommendations',
                                  style: VnText.heading(17, weight: FontWeight.w700, color: p.ink)),
                              for (var i = 0; i < result.recommendations.length; i++) ...[
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle),
                                      child: Text('${i + 1}',
                                          style: VnText.body(13,
                                              weight: FontWeight.w700, color: p.onBrand)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(result.recommendations[i],
                                          style: VnText.body(14, color: p.ink, height: 1.5)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (result.monitorSymptoms.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _WatchForCard(
                          title: result.level == TriageLevel.emergency
                              ? 'On the way, watch for'
                              : 'Get help sooner if you notice',
                          items: result.monitorSymptoms,
                        ),
                      ],
                      if (result.level == TriageLevel.emergency && callable.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Material(
                          color: p.brandWash,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => LaunchHelpers.dialOrSnack(context, callable.first.phone),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.call_outlined, color: p.brandDeep, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Let ${callable.first.name.split(' ').first} know: tap to call from your care circle.',
                                      style: VnText.body(14, color: p.brandDeep),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'This is guidance, not a diagnosis. Only a clinician can confirm the cause.',
                        style: VnText.body(12, color: p.muted, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: VnOutlineButton(
                              label: 'New check',
                              borderColor: p.brand,
                              foreground: p.brand,
                              onPressed: () {
                                ref.read(chatMessagesProvider.notifier).clear();
                                context.go('/chat');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: VnOutlineButton(
                              label: 'Back to home',
                              background: p.surfaceAlt,
                              borderColor: Colors.transparent,
                              onPressed: () => context.go('/home'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchForCard extends StatelessWidget {
  final String title;
  final List<String> items;
  const _WatchForCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final fg = p.isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF2A2010) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.isDark ? const Color(0xFF5C4515) : const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VnText.heading(17, weight: FontWeight.w700, color: fg)),
          const SizedBox(height: 10),
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9, right: 10, left: 4),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text(s, style: VnText.body(14, color: fg, height: 1.6))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
