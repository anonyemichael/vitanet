import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:url_launcher/url_launcher.dart';

class FirstAidTip {
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final List<String> steps;
  final String whenToSeekHelp;
  final String? imageUrl;
  final String? videoUrl;

  const FirstAidTip({
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.steps,
    required this.whenToSeekHelp,
    this.imageUrl,
    this.videoUrl,
  });
}

/// Designed First Aid Tips feature — practical guidance, not a diagnosis.
class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  static const tips = <FirstAidTip>[
    FirstAidTip(
      title: 'Cuts & scrapes',
      summary: 'Clean the wound and protect it while it heals.',
      icon: Icons.healing_rounded,
      accent: Color(0xFF0D9488),
      steps: [
        'Wash your hands before touching the wound.',
        'Rinse with clean water to remove dirt.',
        'Apply gentle pressure with a clean cloth if bleeding.',
        'Use an antiseptic if available, then cover with a sterile bandage.',
      ],
      whenToSeekHelp:
          'Seek care for deep wounds, heavy bleeding, animal bites, or signs of infection.',
      imageUrl: 'https://images.unsplash.com/photo-1584362917165-526a968579e8?auto=format&fit=crop&q=80&w=800',
      videoUrl: 'https://www.youtube.com/watch?v=4eMQvdDYXqk',
    ),
    FirstAidTip(
      title: 'Burns (minor)',
      summary: 'Cool the burn quickly and keep the area clean.',
      icon: Icons.local_fire_department_rounded,
      accent: Color(0xFFD97706),
      steps: [
        'Cool under cool running water for 10–20 minutes.',
        'Remove tight items near the area before swelling starts.',
        'Cover loosely with a sterile non-fluffy dressing.',
        'Do not apply ice, butter, or toothpaste.',
      ],
      whenToSeekHelp:
          'Get urgent help for large burns, chemical/electrical burns, or burns on face, hands, or genitals.',
    ),
    FirstAidTip(
      title: 'Sprains & strains',
      summary: 'Rest, ice, compression, and elevation (RICE).',
      icon: Icons.accessibility_new_rounded,
      accent: Color(0xFF6366F1),
      steps: [
        'Rest the injured area and avoid weight-bearing if painful.',
        'Apply a cold pack wrapped in cloth for 15–20 minutes.',
        'Use a soft bandage for light compression if comfortable.',
        'Elevate the limb when possible.',
      ],
      whenToSeekHelp:
          'Seek care if you cannot bear weight, see severe swelling/deformity, or pain worsens.',
    ),
    FirstAidTip(
      title: 'Choking (adult)',
      summary:
          'Encourage coughing; use back blows / abdominal thrusts if needed.',
      icon: Icons.emergency_rounded,
      accent: Color(0xFFEF4444),
      steps: [
        'Ask “Are you choking?” If they can cough or speak, encourage coughing.',
        'If they cannot breathe, call emergency services immediately.',
        'Give up to 5 firm back blows between the shoulder blades.',
        'If still blocked, give up to 5 abdominal thrusts (Heimlich).',
      ],
      whenToSeekHelp:
          'Call emergency services right away if the person cannot breathe, cough, or speak.',
    ),
    FirstAidTip(
      title: 'Fever at home',
      summary: 'Support comfort while watching for warning signs.',
      icon: Icons.thermostat_rounded,
      accent: Color(0xFF0F766E),
      steps: [
        'Rest and drink fluids regularly.',
        'Dress lightly and keep the room comfortably cool.',
        'Use fever reducers only as directed on the label.',
        'Track temperature and how you feel over 24–48 hours.',
      ],
      whenToSeekHelp:
          'Seek urgent care for very high fever, stiff neck, confusion, rash, or breathing trouble.',
    ),
    FirstAidTip(
      title: 'Nosebleeds',
      summary: 'Sit forward and pinch — do not tip the head back.',
      icon: Icons.water_drop_rounded,
      accent: Color(0xFFDB2777),
      steps: [
        'Sit upright and lean slightly forward.',
        'Pinch the soft part of the nose for 10–15 minutes.',
        'Breathe through your mouth and stay calm.',
        'Avoid packing the nose with tissue while bleeding heavily.',
      ],
      whenToSeekHelp:
          'Get help if bleeding lasts over 20 minutes, follows an injury, or you feel faint.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First Aid Tips')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer.withValues(
                alpha: 0.7,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'These tips are general first-aid guidance only — not a diagnosis or substitute for emergency care.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Choose a situation',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...tips.map((tip) => _TipCard(tip: tip)),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final FirstAidTip tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDetail(context),
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: tip.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(tip.icon, color: tip.accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.summary,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => FirstAidDetailScreen(tip: tip)));
  }
}

class FirstAidDetailScreen extends StatelessWidget {
  final FirstAidTip tip;

  const FirstAidDetailScreen({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tip.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tip.accent, tip.accent.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(tip.icon, color: Colors.white, size: 36),
                const SizedBox(height: AppSpacing.md),
                Text(
                  tip.title,
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tip.summary,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          if (tip.imageUrl != null) ...[
            const SizedBox(height: AppSpacing.xl),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Image.network(
                tip.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: context.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_rounded, size: 48, color: context.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
          if (tip.videoUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(tip.videoUrl!)),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Watch Video Tutorial'),
              style: FilledButton.styleFrom(
                backgroundColor: context.colorScheme.primaryContainer,
                foregroundColor: context.colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Text('Steps', style: context.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(tip.steps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tip.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: tip.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      tip.steps[i],
                      style: context.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colorScheme.errorContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: context.colorScheme.error.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When to seek help',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tip.whenToSeekHelp,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
