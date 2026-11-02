import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/features/resources/models/health_video.dart';
import 'package:vitanet/features/resources/screens/emergency_protocols_screen.dart';
import 'package:vitanet/features/resources/screens/video_library_screen.dart';
import 'package:vitanet/features/resources/screens/video_player_screen.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';
import 'package:vitanet/features/resources/widgets/video_widgets.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class FirstAidTip {
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final List<String> steps;
  final String whenToSeekHelp;
  final String? imageUrl;
  final String? videoUrl;

  /// Short recognition cue shown in protocol lists ("Unresponsive, not breathing").
  final String? cue;

  /// Optional bold heading for each entry in [steps].
  final List<String> stepTitles;

  /// Who the guide is written for ("Adults & teens").
  final String audience;

  const FirstAidTip({
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    required this.steps,
    required this.whenToSeekHelp,
    this.imageUrl,
    this.videoUrl,
    this.cue,
    this.stepTitles = const [],
    this.audience = 'Adults & teens',
  });

  String get lowerTitle => title.toLowerCase();

  bool get isCpr => lowerTitle.contains('cpr');

  /// Life-threatening protocols (shown first, red styling).
  bool get isCritical {
    final t = lowerTitle;
    return t.contains('cpr') ||
        t.contains('chok') ||
        t.contains('heart') ||
        t.contains('severe bleed') ||
        t.contains('hemorrhage') ||
        t.contains('anaphylaxis') ||
        t.contains('allergic') ||
        t.contains('seizure');
  }

  String stepTitle(int i) =>
      i < stepTitles.length ? stepTitles[i] : 'Step ${i + 1}';
}

/// Designed First Aid feature: the static, offline-ready protocol catalog.
/// Its screen is the emergency protocol list.
class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  static const tips = <FirstAidTip>[
    FirstAidTip(
      title: 'CPR (adult, hands-only)',
      summary:
          'For someone who is unresponsive and not breathing normally. Keep going until help arrives.',
      icon: Icons.favorite_rounded,
      accent: Color(0xFFDC2626),
      cue: 'Unresponsive, not breathing',
      stepTitles: [
        'Check for danger and a response',
        'Call for help',
        'Place your hands',
        'Push hard and fast',
        'Use an AED',
      ],
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
      cue: 'Clean, close, cover',
      stepTitles: [
        'Wash your hands',
        'Rinse the wound',
        'Stop the bleeding',
        'Cover it',
      ],
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
      title: 'Severe Bleeding (Hemorrhage)',
      summary: 'Apply direct pressure immediately and elevate the wound.',
      icon: Icons.water_drop_rounded,
      accent: Color(0xFFDC2626),
      cue: 'Pressure, packing, tourniquet',
      stepTitles: [
        'Call for help',
        'Press firmly',
        'Add, don\'t remove',
        'Raise the limb',
        'Tourniquet if needed',
      ],
      steps: [
        'Call emergency services immediately for profuse or spurting arterial bleeding.',
        'Apply firm, continuous direct pressure with a sterile dressing or clean cloth.',
        'Do not remove blood-soaked dressings; place additional clean dressings directly over them.',
        'Elevate the injured limb above heart level if no bone fracture is suspected.',
        'If limb bleeding is catastrophic and unmanageable, apply a medical tourniquet 2–3 inches above the wound.',
      ],
      whenToSeekHelp:
          'Seek emergency dispatch immediately if blood is spurting, will not stop after 10 minutes of pressure, or the person feels faint.',
      videoUrl: null,
    ),
    FirstAidTip(
      title: 'Burns (minor)',
      summary: 'Cool the burn quickly with running water and protect the skin.',
      icon: Icons.local_fire_department_rounded,
      accent: Color(0xFFB45309),
      cue: 'Cool water 20 min',
      stepTitles: [
        'Cool the burn',
        'Remove jewellery',
        'Cover loosely',
        'Avoid home remedies',
        'Leave blisters alone',
        'Ease the pain',
      ],
      steps: [
        'Immediately hold the burned area under cool running water for 10–20 minutes.',
        'Gently remove rings, watches, or restrictive clothing near the burn before swelling begins.',
        'Cover loosely with sterile, non-adherent dressing or clean plastic wrap.',
        'Never apply ice, iced water, butter, oils, or toothpaste to a burn.',
        'Protect intact blisters: do not puncture or pop burn blisters to prevent infection.',
        'Take an OTC pain reliever (such as acetaminophen or ibuprofen) if needed.',
      ],
      whenToSeekHelp:
          'Get urgent medical help for large burns, chemical or electrical burns, or burns affecting the face, hands, joints, or groin.',
      videoUrl: 'EaJmzB8gE_o',
    ),
    FirstAidTip(
      title: 'Sprains & strains',
      summary: 'Rest, ice, compression, and elevation (RICE).',
      icon: Icons.accessibility_new_rounded,
      accent: Color(0xFF6366F1),
      cue: 'Rest, ice, compress',
      stepTitles: ['Rest', 'Ice', 'Compress', 'Elevate'],
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
      accent: Color(0xFFDC2626),
      cue: "Can't speak, cough or breathe",
      stepTitles: [
        'Ask and encourage coughing',
        'Call for help',
        'Back blows',
        'Abdominal thrusts',
      ],
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
      cue: 'Fluids, rest, monitor',
      stepTitles: [
        'Rest and drink',
        'Stay cool',
        'Use medicine carefully',
        'Keep track',
      ],
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
      cue: 'Lean forward, pinch',
      stepTitles: [
        'Lean forward',
        'Pinch the nose',
        'Breathe through your mouth',
        'Don\'t pack the nose',
      ],
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
      summary:
          'Recognize chest pain, shortness of breath, and seek urgent care.',
      icon: Icons.monitor_heart_rounded,
      accent: Color(0xFFDC2626),
      cue: 'Chest pain, arm or jaw pain',
      stepTitles: [
        'Call for help',
        'Sit them down',
        'Loosen clothing',
        'Help with their medicine',
        'Be ready for CPR',
      ],
      steps: [
        'Call emergency services immediately if you suspect a heart attack.',
        'Have the person sit down, rest, and try to keep calm.',
        'Loosen any tight clothing.',
        'Ask if they take chest pain medication (like nitroglycerin) and help them take it.',
        'If they are unresponsive and not breathing, begin CPR.',
      ],
      whenToSeekHelp:
          'Call local emergency services immediately for chest pain, pain spreading to arms/neck, or severe shortness of breath.',
    ),
    FirstAidTip(
      title: 'Allergic Reactions (Anaphylaxis)',
      summary:
          'Use an epinephrine auto-injector if available and call for help.',
      icon: Icons.sick_rounded,
      accent: Color(0xFFDC2626),
      cue: 'Swelling, hives, wheeze · use EpiPen',
      stepTitles: [
        'Call for help',
        'Use their EpiPen',
        'Lie them down',
        'Nothing by mouth',
        'Be ready for CPR',
      ],
      steps: [
        'Call emergency services immediately.',
        'Ask if they carry an epinephrine auto-injector (EpiPen) and help them use it.',
        'Have the person lie down face up, and elevate their legs if possible.',
        'Do not give them anything by mouth.',
        'If they stop breathing, begin CPR.',
      ],
      whenToSeekHelp:
          'Call local emergency services immediately if they have trouble breathing, swelling of the throat/tongue, or faintness.',
    ),
    FirstAidTip(
      title: 'Seizures',
      summary: 'Keep the person safe, protect the head and time the seizure.',
      icon: Icons.bolt_rounded,
      accent: Color(0xFFDC2626),
      cue: 'Protect the head, time it',
      audience: 'All ages',
      stepTitles: [
        'Stay calm and time it',
        'Protect the head',
        'Don\'t hold them down',
        'Recovery position',
        'Stay with them',
      ],
      steps: [
        'Stay calm and note the time the seizure started.',
        'Move hard or sharp objects away and cushion the head with something soft.',
        'Do not restrain the person or put anything in their mouth.',
        'When the jerking stops, gently roll them onto their side into the recovery position.',
        'Stay until they are fully awake. Call emergency services if it lasts over 5 minutes, repeats, they are injured, or it is their first seizure.',
      ],
      whenToSeekHelp:
          'Call emergency services if a seizure lasts more than 5 minutes, another follows, the person is injured, pregnant, has trouble breathing afterwards, or has never had a seizure before.',
    ),
  ];

  @override
  Widget build(BuildContext context) => const EmergencyProtocolsScreen();
}

/// Step-by-step protocol guide (FirstAid design): designed hero, tickable
/// steps, CPR metronome, demonstration video and a sticky call bar.
class EmergencyProtocolDetailScreen extends ConsumerStatefulWidget {
  final FirstAidTip tip;
  final String emergencyNumber;

  const EmergencyProtocolDetailScreen({
    super.key,
    required this.tip,
    this.emergencyNumber = '112',
  });

  @override
  ConsumerState<EmergencyProtocolDetailScreen> createState() =>
      _EmergencyProtocolDetailScreenState();
}

/// Legacy alias for screen & navigation compatibility
typedef FirstAidDetailScreen = EmergencyProtocolDetailScreen;

class _EmergencyProtocolDetailScreenState
    extends ConsumerState<EmergencyProtocolDetailScreen> {
  final Set<int> _completedSteps = {};
  bool _isBookmarked = false;

  void _toggleStep(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_completedSteps.remove(index)) _completedSteps.add(index);
    });
  }

  void _toggleBookmark() {
    setState(() => _isBookmarked = !_isBookmarked);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _isBookmarked
                ? 'Saved to Emergency Quick-Access'
                : 'Removed from Quick-Access',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// CPR opens the video library on the first-aid topic; other guides play
  /// their own demonstration video.
  void _openDemonstration(ClinicalVideo? cprVideo) {
    final tip = widget.tip;
    if (tip.isCpr) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => const VideoLibraryScreen(initialTopic: 'First aid'),
        ),
      );
      return;
    }
    if (tip.videoUrl == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          emergencyNumber: widget.emergencyNumber,
          video: HealthVideo(
            videoId: tip.videoUrl!,
            title: '${tip.title} Technique Demo',
            thumbnailUrl:
                'https://img.youtube.com/vi/${tip.videoUrl!}/hqdefault.jpg',
            duration: 'Demo',
            category: 'First Aid',
            organization: 'Official Clinical Guidance',
            summary: tip.summary,
            keySteps: tip.steps
                .asMap()
                .entries
                .map(
                  (e) => VideoKeyStep(
                    time: 'Step ${e.key + 1}',
                    action: tip.stepTitle(e.key),
                  ),
                )
                .toList(),
            verificationStatus: 'Verified Medical Guideline',
          ),
        ),
      ),
    );
  }

  ClinicalVideo? get _cprCatalogVideo {
    for (final v in ClinicalVideoRepository.verifiedMasterclasses) {
      if (isCprVideo(v)) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final tip = widget.tip;
    final number = widget.emergencyNumber;
    final cprVideo = tip.isCpr ? _cprCatalogVideo : null;
    final hasDemo = tip.isCpr || tip.videoUrl != null;

    return Scaffold(
      backgroundColor: p.page,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => handleScrollNotification(n, ref),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  _ProtocolHero(tip: tip),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    left: 16,
                    child: VnIconButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Back',
                      iconSize: 26,
                      background: Colors.white,
                      foreground: const Color(0xFF0F172A),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    right: 16,
                    child: VnIconButton(
                      icon: _isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      tooltip: _isBookmarked
                          ? 'Remove saved guide'
                          : 'Save guide',
                      background: Colors.white,
                      foreground: _isBookmarked
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF0F172A),
                      onPressed: _toggleBookmark,
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.page,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _kReadableWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (tip.isCritical)
                              const VnTag(
                                label: 'LIFE-THREATENING',
                                bg: Color(0xFFFEE2E2),
                                fg: Color(0xFF991B1B),
                                fontSize: 12,
                                weight: FontWeight.w800,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                              )
                            else
                              const VnTag(
                                label: 'URGENT BUT MANAGEABLE',
                                bg: Color(0xFFFFEDD5),
                                fg: Color(0xFF9A3412),
                                fontSize: 12,
                                weight: FontWeight.w800,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                              ),
                            VnTag(
                              label: tip.audience,
                              bg: const Color(0xFFF1F5F9),
                              fg: const Color(0xFF475569),
                              fontSize: 12,
                              weight: FontWeight.w600,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: Text(
                            tip.isCpr ? 'CPR: hands-only' : tip.title,
                            style: VnText.heading(
                              26,
                              color: p.ink,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tip.summary,
                          style: VnText.body(15, color: p.inkSoft, height: 1.5),
                        ),
                        if (tip.isCpr) ...[
                          const SizedBox(height: 16),
                          const _MetronomeCard(),
                        ],
                        const SizedBox(height: 16),
                        for (var i = 0; i < tip.steps.length; i++) ...[
                          _StepCard(
                            index: i,
                            title: tip.stepTitle(i),
                            body: tip.steps[i],
                            done: _completedSteps.contains(i),
                            onTap: () => _toggleStep(i),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 6),
                        _SeekHelpCard(
                          text: tip.whenToSeekHelp.replaceAll('911', number),
                        ),
                        if (hasDemo) ...[
                          const SizedBox(height: 16),
                          _DemoCard(
                            tip: tip,
                            subtitle: tip.isCpr && cprVideo != null
                                ? '${cprVideo.channelName} · ${cprVideo.formattedDuration}'
                                : 'Video demonstration',
                            onTap: () => _openDemonstration(cprVideo),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.line)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kReadableWidth),
            child: VnButton(
              label: 'Call $number · Put on speaker',
              icon: Icons.phone_rounded,
              background: const Color(0xFFB91C1C),
              foreground: Colors.white,
              onPressed: () => LaunchHelpers.dialOrSnack(context, number),
            ),
          ),
        ),
      ),
    );
  }
}

/// Readable max width for protocol content on tablets / desktop.
const double _kReadableWidth = 720;

// ─────────────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────────────

class _ProtocolHero extends StatelessWidget {
  final FirstAidTip tip;
  const _ProtocolHero({required this.tip});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final critical = tip.isCritical;
    final bg = critical ? const Color(0xFF7F1D1D) : const Color(0xFF7C2D12);
    final ringColor = critical
        ? const Color(0xFFFECACA)
        : const Color(0xFFFED7AA);
    return Semantics(
      image: true,
      label: tip.isCpr
          ? 'CPR: hands stacked in the centre of the chest'
          : tip.title,
      excludeSemantics: true,
      // Full-bleed: the hero sits in a loose Stack, so without an explicit
      // width it shrank to its 300px ring and hugged the top-left corner on
      // wide screens.
      child: Container(
        width: double.infinity,
        height: 240 + top,
        color: bg,
        padding: EdgeInsets.only(top: top),
        child: ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(300, ringColor.withValues(alpha: 0.15)),
              _ring(210, ringColor.withValues(alpha: 0.22)),
              if (tip.isCpr)
                const CustomPaint(
                  size: Size(150, 150),
                  painter: _CprHeartPainter(),
                )
              else
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: critical
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFFC2410C),
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 3),
                  ),
                  child: Icon(tip.icon, size: 56, color: Colors.white),
                ),
              Positioned(
                right: math.max(
                  16,
                  (MediaQuery.sizeOf(context).width - _kReadableWidth) / 2 + 16,
                ),
                bottom: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tip.isCpr ? '100–120' : '${tip.steps.length} steps',
                      style: VnText.heading(30, color: Colors.white, height: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tip.isCpr
                          ? 'pushes per minute'
                          : (tip.cue ?? 'first aid guide'),
                      style: VnText.body(
                        12,
                        weight: FontWeight.w600,
                        color: ringColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color),
    ),
  );
}

/// Heart with a pulse trace and a downward "push" arrow (FirstAid design SVG,
/// 120x120 viewBox).
class _CprHeartPainter extends CustomPainter {
  const _CprHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.scale(s);

    final heart = Path()
      ..moveTo(60, 104)
      ..lineTo(22, 66)
      ..arcToPoint(const Offset(53, 35), radius: const Radius.circular(22))
      ..lineTo(60, 42)
      ..lineTo(67, 35)
      ..arcToPoint(const Offset(98, 66), radius: const Radius.circular(22))
      ..close();
    canvas.drawPath(heart, Paint()..color = const Color(0xFFB91C1C));
    canvas.drawPath(
      heart,
      Paint()
        ..color = const Color(0xFFFECACA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    final pulse = Path()
      ..moveTo(30, 64)
      ..lineTo(46, 64)
      ..lineTo(52, 52)
      ..lineTo(62, 74)
      ..lineTo(68, 64)
      ..lineTo(90, 64);
    canvas.drawPath(
      pulse,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final arrow = Path()
      ..moveTo(60, 8)
      ..lineTo(60, 24)
      ..moveTo(52, 16)
      ..lineTo(60, 24)
      ..lineTo(68, 16);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0xFFFECACA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Metronome (110 beats per minute, haptic + click)
// ─────────────────────────────────────────────────────────────────────────────

class _MetronomeCard extends StatefulWidget {
  const _MetronomeCard();

  @override
  State<_MetronomeCard> createState() => _MetronomeCardState();
}

class _MetronomeCardState extends State<_MetronomeCard>
    with SingleTickerProviderStateMixin {
  static const _bpm = 110;
  Timer? _timer;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  int _beats = 0;

  bool get _running => _timer != null;

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _timer = null);
      return;
    }
    _beats = 0;
    _beat();
    setState(() {
      _timer = Timer.periodic(
        const Duration(milliseconds: 60000 ~/ _bpm),
        (_) => _beat(),
      );
    });
  }

  void _beat() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    _pulse.forward(from: 0);
    if (mounted) setState(() => _beats++);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: 1 + (1 - _pulse.value) * (_running ? 0.12 : 0),
              child: child,
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2DD4BF), width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                '$_bpm',
                style: VnText.heading(14, color: const Color(0xFF5EEAD4)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compression rhythm',
                  style: VnText.body(
                    15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _running
                      ? 'Push on every beat · $_beats compressions'
                      : '100–120 per minute, 5–6 cm deep',
                  style: VnText.body(13, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Tooltip(
            message: _running ? 'Stop metronome' : 'Start metronome',
            child: Semantics(
              button: true,
              label: _running ? 'Stop metronome' : 'Start metronome',
              excludeSemantics: true,
              child: Material(
                color: const Color(0xFF2DD4BF),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _toggle,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: const Color(0xFF04201D),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Steps, help callout, demo
// ─────────────────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int index;
  final String title;
  final String body;
  final bool done;
  final VoidCallback onTap;

  const _StepCard({
    required this.index,
    required this.title,
    required this.body,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      checked: done,
      label: 'Step ${index + 1}: $title. $body',
      excludeSemantics: true,
      child: VnCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.all(14),
        color: done ? p.brandWash : p.surface,
        borderColor: done ? p.brandBorder : p.line,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: done ? const Color(0xFF0F766E) : p.surfaceAlt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : Text(
                      '${index + 1}',
                      style: VnText.body(
                        14,
                        weight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: VnText.body(
                      15,
                      weight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: VnText.body(13, color: p.inkSoft, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekHelpCard extends StatelessWidget {
  final String text;
  const _SeekHelpCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final fg = p.isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF2A1212) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: p.isDark ? const Color(0xFF5B1D1D) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: p.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When to get urgent help',
                  style: VnText.body(14, weight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 2),
                Text(text, style: VnText.body(13, color: fg, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final FirstAidTip tip;
  final String subtitle;
  final VoidCallback onTap;
  const _DemoCard({
    required this.tip,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return VnCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(10),
      semanticLabel: 'Watch the demonstration. $subtitle',
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 56,
              child: tip.isCpr
                  ? const CprMiniThumbnail()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        VnNetworkPhoto(
                          url:
                              'https://img.youtube.com/vi/${tip.videoUrl}/hqdefault.jpg',
                          fallbackAsset: VnPhotos.forTopic(
                            tip.title,
                            fallback: VnPhotos.firstAidKit,
                          ),
                          cacheWidth: 300,
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watch the demonstration',
                  style: VnText.body(14, weight: FontWeight.w700, color: p.ink),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: VnText.body(12, color: p.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.faint),
        ],
      ),
    );
  }
}
