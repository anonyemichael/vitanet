import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
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
    final isWideDesktop = width >= 1260;

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
                  constraints: BoxConstraints(maxWidth: isWideDesktop ? 880 : 620),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                    child: _buildRoleSelector(p, isDesktop: true, isWideDesktop: isWideDesktop),
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
              child: _buildRoleSelector(p, isDesktop: false, isWideDesktop: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(VnPalette p, {required bool isDesktop, required bool isWideDesktop}) {
    final hospitalSelected =
        ref.watch(activeWorkspaceProvider) == AppWorkspace.hospital;
    final personalCard = _WorkspaceCard(
      image: 'assets/images/photos/doctor_with_patient.jpg',
      imageAlt: 'Doctor consulting with smiling patient in clinical room',
      title: 'Personal user',
      subtitle: 'Check symptoms and manage your health securely',
      icon: Icons.favorite_outline_rounded,
      selected: !hospitalSelected,
      onTap: () async {
        await ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.personal);
        if (!mounted) return;
        final isAuthed = ref.read(authProvider).status == AuthStatus.authenticated;
        if (isAuthed) {
          context.go('/home');
        } else {
          context.push('/login/patient');
        }
      },
    );

    final hospitalCard = _WorkspaceCard(
      image: 'assets/images/photos/medical_team.jpg',
      imageAlt: 'Clinical staff and surgical healthcare team in hospital corridor',
      title: 'Hospital personnel',
      subtitle: 'Access the clinical dashboard and review cases',
      icon: Icons.local_hospital_outlined,
      selected: hospitalSelected,
      onTap: () async {
        await ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.hospital);
        if (!mounted) return;
        final isAuthed = ref.read(authProvider).status == AuthStatus.authenticated;
        final isStaff = ref.read(staffAccessProvider).valueOrNull?.isPortalUser ?? false;
        if (isAuthed && isStaff) {
          context.go('/admin');
        } else {
          context.push('/login/hospital_personnel');
        }
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDesktop) ...[
          // Mobile header
          Row(
            children: [
              const VitaNetLogo(size: 36),
              const SizedBox(width: 10),
              Text(
                'VitaNet',
                style: VnText.heading(20, weight: FontWeight.w800, color: p.ink),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],

        // Screen title & subtitle
        Semantics(
          header: true,
          child: Text(
            'How will you use VitaNet?',
            style: VnText.heading(isDesktop ? 32 : 30,
                weight: FontWeight.w800, color: p.ink, height: 1.15),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Pick one. You can switch later from Settings.',
          style: VnText.body(15, color: p.muted, height: 1.5),
        ),
        const SizedBox(height: 28),

        // Workspace Cards: 2-column Row on wide desktop, vertical Column otherwise
        if (isWideDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: personalCard),
              const SizedBox(width: 20),
              Expanded(child: hospitalCard),
            ],
          )
        else ...[
          personalCard,
          const SizedBox(height: 18),
          hospitalCard,
        ],
        const SizedBox(height: 40),

        // Legal footnote
        Text.rich(
          TextSpan(
            style: VnText.body(13, color: p.muted, height: 1.5),
            children: [
              const TextSpan(text: 'By continuing you agree to the '),
              TextSpan(
                text: 'Privacy Policy',
                recognizer: _privacyTap,
                style: VnText.body(13, weight: FontWeight.w600, color: p.brand),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Medical Disclaimer',
                recognizer: _disclaimerTap,
                style: VnText.body(13, weight: FontWeight.w600, color: p.brand),
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

/// Photo-led workspace choice card from the redesign: full-bleed photo,
/// title + one-line subtitle, chevron. The selected card gets a brand
/// border and a check badge over the photo.
class _WorkspaceCard extends StatelessWidget {
  final String image;
  final String imageAlt;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceCard({
    required this.image,
    required this.imageAlt,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? p.brand : p.line,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2.3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      image,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.2),
                      semanticLabel: imageAlt,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: p.brandWash,
                        alignment: Alignment.center,
                        child: Icon(icon, size: 40, color: p.brand),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: p.brand,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: VnText.heading(18,
                                weight: FontWeight.w700, color: p.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: VnText.body(14, color: p.muted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.chevron_right_rounded, size: 24, color: p.muted),
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
