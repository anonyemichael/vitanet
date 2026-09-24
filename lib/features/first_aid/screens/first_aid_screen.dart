import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../resources/screens/video_player_screen.dart';
import '../../resources/models/health_video.dart';

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
      title: 'CPR (adult, hands-only)',
      summary:
          'Call emergency services, then push hard and fast in the centre of the chest.',
      icon: Icons.favorite_rounded,
      accent: Color(0xFFDC2626),
      steps: [
        'Check that the scene is safe and the person is unresponsive and not breathing normally.',
        'Call local emergency services and ask someone to get an AED if one is available.',
        'Place both hands in the centre of the chest and keep your arms straight.',
        'Give continuous, hard and fast chest compressions until help takes over or the person shows signs of life.',
        'Use an AED as soon as it is available and follow its voice prompts.',
      ],
      whenToSeekHelp:
          'This is an emergency. Call local emergency services immediately. CPR training is strongly recommended.',
      videoUrl: 'M4ZcSlKROXg',
    ),
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
      videoUrl: '4eBzmDkIAiw',
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
      videoUrl: 'EaJmzB8gE_o',
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
      videoUrl: 'W3Z1Yy2U5kY',
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
      videoUrl: 'PA9hpOnvtTg',
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
      videoUrl: 'sOa35n9ZwtY',
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
      videoUrl: 'Z6bF4F4Y1oM',
    ),
    FirstAidTip(
      title: 'Heart Attack Signs',
      summary: 'Recognize chest pain, shortness of breath, and seek urgent care.',
      icon: Icons.monitor_heart_rounded,
      accent: Color(0xFFE11D48),
      steps: [
        'Call emergency services immediately if you suspect a heart attack.',
        'Have the person sit down, rest, and try to keep calm.',
        'Loosen any tight clothing.',
        'Ask if they take chest pain medication (like nitroglycerin) and help them take it.',
        'If they are unresponsive and not breathing, begin CPR.',
      ],
      whenToSeekHelp:
          'Call 911 immediately for chest pain, pain spreading to arms/neck, or severe shortness of breath.',
    ),
    FirstAidTip(
      title: 'Allergic Reactions (Anaphylaxis)',
      summary: 'Use an epinephrine auto-injector if available and call for help.',
      icon: Icons.sick_rounded,
      accent: Color(0xFF8B5CF6),
      steps: [
        'Call emergency services immediately.',
        'Ask if they carry an epinephrine auto-injector (EpiPen) and help them use it.',
        'Have the person lie down face up, and elevate their legs if possible.',
        'Do not give them anything by mouth.',
        'If they stop breathing, begin CPR.',
      ],
      whenToSeekHelp:
          'Call 911 immediately if they have trouble breathing, swelling of the throat/tongue, or faintness.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('First Aid Tips'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.2)),
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
                      color: context.colorScheme.onSurfaceVariant,
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
      appBar: AppBar(
        title: Text(tip.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          120, // Add bottom padding to prevent nav bar from covering content
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(color: tip.accent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tip.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tip.icon, color: tip.accent, size: 32),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  tip.title,
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tip.summary,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
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
                  child: Icon(
                    Icons.broken_image_rounded,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          if (tip.videoUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      video: HealthVideo(
                        videoId: tip.videoUrl!,
                        title: '${tip.title} Tutorial',
                        thumbnailUrl: 'https://img.youtube.com/vi/${tip.videoUrl!}/hqdefault.jpg',
                        duration: '',
                        category: 'First Aid',
                        organization: 'Emergency Guidance',
                        summary: tip.summary,
                        keySteps: tip.steps.map((step) => VideoKeyStep(time: '•', action: step)).toList(),
                        verificationStatus: 'Verified Medical Guideline',
                      ),
                    ),
                  ),
                );
              },
              icon: Icon(Icons.play_circle_outline_rounded, color: context.colorScheme.primary),
              label: Text('Play First-Aid Tutorial', style: TextStyle(color: context.colorScheme.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colorScheme.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
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
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: context.colorScheme.error.withValues(alpha: 0.3),
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
                    color: context.isDark ? Colors.white : Colors.black87,
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
