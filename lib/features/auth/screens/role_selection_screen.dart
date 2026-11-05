import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Executive-grade workspace and role selection screen.
///
/// Responsive:
/// - Desktop / Wide (>= 960px): Executive split-screen with enterprise clinical
///   hero showcase on the left and workspace cards on the right.
/// - Mobile / Tablet (< 960px): Clean centered high-density card layout.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 960;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: p.page,
        body: Row(
          children: [
            // Left: Enterprise Brand Showcase (440px)
            const SizedBox(
              width: 440,
              child: _EnterpriseHeroPanel(),
            ),
            // Right: Role Selection Workspace
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                    child: _buildRoleSelector(p, isDesktop: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet layout
    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: _buildRoleSelector(p, isDesktop: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(VnPalette p, {required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDesktop) ...[
          // Mobile header
          Row(
            children: [
              const VitaNetLogo(size: 32),
              const SizedBox(width: 10),
              Text(
                'VitaNet',
                style: VnText.heading(20, weight: FontWeight.w800, color: p.ink),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandWash,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p.brandBorder),
                ),
                child: Text(
                  'HEALTHCARE',
                  style: VnText.heading(10, weight: FontWeight.w700, color: AppColors.brandDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Screen title & subtitle
        Semantics(
          header: true,
          child: Text(
            'Select your workspace',
            style: VnText.heading(isDesktop ? 28 : 24, weight: FontWeight.w800, color: p.ink),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want to use VitaNet. You can fluidly switch workspaces anytime from your profile.',
          style: VnText.body(14, color: p.muted, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Workspace Card 1: Personal User
        _WorkspaceCard(
          image: 'assets/images/photos/doctor_with_patient.jpg',
          imageAlt: 'Doctor consulting with smiling patient in clinical room',
          badgeText: 'PATIENTS & CAREGIVERS',
          title: 'Personal Health',
          subtitle: 'Assess symptoms, track vitals, send ER pre-arrivals, and review hospital admission summaries.',
          icon: Icons.favorite_outline_rounded,
          actionLabel: 'Enter Personal Health',
          bullets: const [
            'Instant AI triage & symptom severity analysis',
            '1-Tap ER pre-arrival check-in with GPS drive ETA',
            'Inpatient hospital stay records & discharge notes',
          ],
          isPrimary: true,
          onTap: () {
            ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.personal);
            context.push('/login/patient');
          },
        ),
        const SizedBox(height: 18),

        // Workspace Card 2: Hospital Personnel
        _WorkspaceCard(
          image: 'assets/images/photos/medical_team.jpg',
          imageAlt: 'Clinical staff and surgical healthcare team in hospital corridor',
          badgeText: 'CLINICAL STAFF & HMS',
          title: 'Hospital Personnel',
          subtitle: 'Manage ward bed occupancy, emergency triage cases, physician medication orders, and vital signs flow sheets.',
          icon: Icons.local_hospital_outlined,
          actionLabel: 'Enter Clinical Portal',
          bullets: const [
            'Real-time bed availability & incoming ER queue',
            'Inpatient vitals flow sheets & nursing flow logs',
            'Physician prescription orders & facility broadcasts',
          ],
          isPrimary: false,
          onTap: () {
            ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.hospital);
            context.push('/login/hospital_personnel');
          },
        ),
        const SizedBox(height: 28),

        // Direct sign-in shortcut
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Already have an account? ', style: VnText.body(13, color: p.muted)),
              VnLink(
                label: 'Sign in directly',
                fontSize: 13,
                weight: FontWeight.w600,
                onTap: () {
                  ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.personal);
                  context.push('/login/patient');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Legal footnote
        Text.rich(
          TextSpan(
            style: VnText.body(12, color: p.faint, height: 1.5),
            children: [
              const TextSpan(text: 'By continuing you agree to the '),
              TextSpan(
                text: 'Privacy Policy',
                recognizer: _privacyTap,
                style: VnText.body(12, weight: FontWeight.w600, color: p.brand),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Medical Disclaimer',
                recognizer: _disclaimerTap,
                style: VnText.body(12, weight: FontWeight.w600, color: p.brand),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Executive dark brand sidebar displayed on desktop.
class _EnterpriseHeroPanel extends StatelessWidget {
  const _EnterpriseHeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.staffNavy,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo & Brand mark
            Row(
              children: [
                const VitaNetLogo(size: 36),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VitaNet',
                      style: VnText.heading(22, weight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      'Clinical & Patient Network',
                      style: VnText.body(12, weight: FontWeight.w500, color: AppColors.mint),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(
                'ENTERPRISE HEALTHCARE SUITE',
                style: VnText.heading(10, weight: FontWeight.w700, color: AppColors.mint),
              ),
            ),
            const SizedBox(height: 16),

            // Main Headline
            Text(
              'One Unified Platform for Patients & Clinical Teams.',
              style: VnText.heading(28, weight: FontWeight.w800, color: Colors.white, height: 1.25),
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting emergency triage, real-time hospital bed telemetry, physician orders, and comprehensive health records in one continuous care loop.',
              style: VnText.body(14, color: const Color(0xFF94A3B8), height: 1.6),
            ),
            const SizedBox(height: 28),

            // High-density Proof Points
            _HeroFeature(
              icon: Icons.bolt_rounded,
              title: 'Emergency Pre-Arrival Dispatch',
              desc: 'Real-time telemetry and haversine drive-time ETA sent directly to ER triage desks.',
            ),
            const SizedBox(height: 16),
            _HeroFeature(
              icon: Icons.monitor_heart_outlined,
              title: 'Live Inpatient Vitals Flow Sheets',
              desc: 'Continuous bedside telemetry, nurse observations, and physician medication orders.',
            ),
            const SizedBox(height: 16),
            _HeroFeature(
              icon: Icons.verified_user_outlined,
              title: 'Enterprise Governance & Security',
              desc: 'Role-based clinical authorization, tamper-evident audit logs, and HIPAA alignment.',
            ),

            const SizedBox(height: 36),

            // Security Trust Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.mint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'HIPAA & HL7-Ready • 256-Bit Encrypted • Verified Provider Network',
                      style: VnText.body(11, color: const Color(0xFF94A3B8)),
                    ),
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

class _HeroFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _HeroFeature({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, size: 16, color: AppColors.mint),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: VnText.heading(13, weight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: VnText.body(12, color: const Color(0xFF94A3B8), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// High-density clinical workspace card.
class _WorkspaceCard extends StatelessWidget {
  final String image;
  final String imageAlt;
  final String badgeText;
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final List<String> bullets;
  final bool isPrimary;
  final VoidCallback onTap;

  const _WorkspaceCard({
    required this.image,
    required this.imageAlt,
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.bullets,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isPrimary ? AppColors.brand : p.line,
            width: isPrimary ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: p.brandWash.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full-bleed Image Header with dark cinematic gradient & floating badges
              SizedBox(
                height: 145,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      image,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.3),
                      semanticLabel: imageAlt,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 13,
                              color: isPrimary ? AppColors.mintLight : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              badgeText,
                              style: VnText.heading(10,
                                  weight: FontWeight.w700,
                                  color: isPrimary ? AppColors.mintLight : Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isPrimary ? AppColors.brand : Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: VnText.heading(18, weight: FontWeight.w700, color: p.ink),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      subtitle,
                      style: VnText.body(13, color: p.muted, height: 1.45),
                    ),
                    const SizedBox(height: 14),

                    // Feature checkmarks
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: bullets.map((bullet) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 15,
                                  color: AppColors.brand,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: VnText.body(12,
                                        weight: FontWeight.w500, color: p.ink),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bottom CTA button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          actionLabel,
                          style: VnText.heading(13,
                              weight: FontWeight.w700,
                              color: isPrimary ? AppColors.brand : p.ink),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: isPrimary ? AppColors.brand : p.ink,
                        ),
                      ],
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
}
