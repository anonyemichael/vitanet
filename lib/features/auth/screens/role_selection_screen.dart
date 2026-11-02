import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late final TapGestureRecognizer _privacyTap;
  late final TapGestureRecognizer _disclaimerTap;

  @override
  void initState() {
    super.initState();
    _privacyTap = TapGestureRecognizer()..onTap = () => context.push('/privacy');
    _disclaimerTap = TapGestureRecognizer()
      ..onTap = () => context.push('/disclaimer');
  }

  @override
  void dispose() {
    _privacyTap.dispose();
    _disclaimerTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final patient = _RoleCard(
      image: 'assets/images/photos/doctor_with_patient.jpg',
      alt: 'Doctor chatting with a smiling patient in a hospital bed',
      alignment: const Alignment(0, -0.4),
      title: 'Personal user',
      body: 'Check symptoms and manage your health securely',
      highlighted: true,
      onTap: () => context.push('/login/patient'),
    );
    final staff = _RoleCard(
      image: 'assets/images/photos/medical_team.jpg',
      alt: 'Doctors and nurses standing in a hospital corridor',
      alignment: const Alignment(0, -0.5),
      title: 'Hospital personnel',
      body: 'Access the clinical dashboard and review cases',
      onTap: () => context.push('/login/hospital_personnel'),
    );

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 880 : 560),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              const VitaNetLogo(size: 36),
                              const SizedBox(width: 10),
                              Text('VitaNet', style: VnText.heading(20, color: p.ink)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Semantics(
                          header: true,
                          child: Text('How will you use VitaNet?',
                              style: VnText.heading(28, color: p.ink, height: 1.2)),
                        ),
                        const SizedBox(height: 8),
                        Text('Pick one. You can switch later from Settings.',
                            style: VnText.body(15, color: p.muted, height: 1.5)),
                        const SizedBox(height: 24),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: patient),
                              const SizedBox(width: 20),
                              Expanded(child: staff),
                            ],
                          )
                        else ...[
                          patient,
                          const SizedBox(height: 24),
                          staff,
                        ],
                        const Spacer(),
                        const SizedBox(height: 24),
                        Text.rich(
                          TextSpan(
                            style: VnText.body(12, color: p.muted, height: 1.5),
                            children: [
                              const TextSpan(text: 'By continuing you agree to the '),
                              TextSpan(
                                text: 'Privacy Policy',
                                recognizer: _privacyTap,
                                style: VnText.body(12,
                                    weight: FontWeight.w600, color: p.brand),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Medical Disclaimer',
                                recognizer: _disclaimerTap,
                                style: VnText.body(12,
                                    weight: FontWeight.w600, color: p.brand),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
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
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String image;
  final String alt;
  final Alignment alignment;
  final String title;
  final String body;
  final bool highlighted;
  final VoidCallback onTap;

  const _RoleCard({
    required this.image,
    required this.alt,
    required this.alignment,
    required this.title,
    required this.body,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: highlighted ? p.brand : p.line,
            width: highlighted ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(image,
                        fit: BoxFit.cover, alignment: alignment, semanticLabel: alt),
                    if (highlighted)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle),
                          child: Icon(Icons.check_rounded, size: 16, color: p.onBrand),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: VnText.heading(18,
                                  weight: FontWeight.w700, color: p.ink)),
                          const SizedBox(height: 4),
                          Text(body,
                              style: VnText.body(14, color: p.muted, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.chevron_right_rounded,
                        color: highlighted ? p.brand : p.muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
