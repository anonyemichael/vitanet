import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class _Slide {
  final String image;
  final String alt;
  final IconData icon;
  final String chip;
  final String chipSub;
  final String title;
  final String body;

  const _Slide({
    required this.image,
    required this.alt,
    required this.icon,
    required this.chip,
    required this.chipSub,
    required this.title,
    required this.body,
  });
}

const _slides = <_Slide>[
  _Slide(
    image: 'assets/images/photos/doctor_on_phone.jpg',
    alt: 'Doctor reading a message on a phone',
    icon: Icons.chat_bubble_outline_rounded,
    chip: 'Ask anything',
    chipSub: 'Answers in seconds',
    title: 'Describe how you feel. Get clear next steps.',
    body:
        'Chat with VitaNet AI about symptoms, medicines or lab results. It asks the right follow-up questions, like a triage nurse would.',
  ),
  _Slide(
    image: 'assets/images/photos/smartwatch_wrist.jpg',
    alt: 'Person checking a smartwatch on their wrist',
    icon: Icons.monitor_heart_outlined,
    chip: 'Live vitals',
    chipSub: 'Health Connect · Apple Health',
    title: 'Your vitals, read in context.',
    body:
        'Connect your watch or phone sensors. Heart rate, SpO2, temperature and blood pressure feed straight into every assessment.',
  ),
  _Slide(
    image: 'assets/images/photos/holding_hands.jpg',
    alt: 'Two people holding hands in support',
    icon: Icons.group_outlined,
    chip: 'Care circle',
    chipSub: 'Trusted contacts',
    title: 'The people who matter, in the loop.',
    body:
        'Add family or caregivers. If a check comes back urgent, they get notified with your location so help arrives sooner.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final storage = ref.read(localStorageProvider);
    await storage.setOnboardingComplete();
    ref.read(onboardingCompleteProvider.notifier).state = true;

    // Routes to Login/Role Selection because Onboarding is the true first step.
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _completeOnboarding();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_index + 1} of ${_slides.length}',
                      style: VnText.heading(13, weight: FontWeight.w700, color: p.muted),
                    ),
                    VnLink(label: 'Skip', onTap: _completeOnboarding),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Semantics(
                    label: 'Slide ${_index + 1} of ${_slides.length}',
                    child: Row(
                      children: [
                        for (var k = 0; k < _slides.length; k++) ...[
                          if (k > 0) const SizedBox(width: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 8,
                            width: k == _index ? 28 : 8,
                            decoration: BoxDecoration(
                              color: k == _index
                                  ? p.brand
                                  : (p.isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  VnButton(
                    label: isLast ? 'Get started' : 'Next',
                    icon: Icons.arrow_forward_rounded,
                    iconAfter: true,
                    expand: false,
                    onPressed: _next,
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

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final imageH = (c.maxHeight - 170).clamp(200.0, 400.0);
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: imageH,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      image: true,
                      label: slide.alt,
                      child: Image.asset(slide.image, fit: BoxFit.cover),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F0F172A),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: p.brandTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(slide.icon, size: 20, color: p.brand),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(slide.chip,
                                    style: VnText.body(13,
                                        weight: FontWeight.w700, color: p.ink)),
                                Text(slide.chipSub,
                                    style: VnText.body(12, color: p.muted)),
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
            const SizedBox(height: 28),
            Semantics(
              header: true,
              child: Text(
                slide.title,
                style: VnText.heading(30,
                    color: p.ink, height: 1.2, letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              slide.body,
              style: VnText.body(16, color: p.inkSoft, height: 1.55),
            ),
          ],
        ),
      );
    });
  }
}
