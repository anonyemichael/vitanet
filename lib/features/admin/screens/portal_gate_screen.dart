import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/hospital_form_screen.dart';
import 'package:vitanet/features/admin/screens/portal_shell.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';

/// Signs the user out after confirmation and returns to the login screen.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  // Open cases still assigned to me: warn so they are handed over first.
  final assigned = ref
          .read(dashboardProvider)
          .valueOrNull
          ?.myCases
          .where((c) => c.status != 'discharged')
          .length ??
      0;
  final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => _EndSessionDialog(assigned: assigned),
      ) ??
      false;
  if (!ok || !context.mounted) return;
  await ref.read(authProvider.notifier).signOut();
  if (context.mounted) context.go('/login');
}

/// Entry point for /admin: decides which access-state screen to show from
/// GET /staff/me (via [staffAccessProvider]).
class PortalGate extends ConsumerWidget {
  const PortalGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(staffAccessProvider);
    return access.when(
      loading: () => const _GateLoading(),
      error: (e, _) => AccessStateScreen(
        icon: Icons.cloud_off_rounded,
        tone: StaffTone.danger,
        title: "Couldn't check your access",
        message: apiErrorMessage(e),
        primaryLabel: 'Retry',
        onPrimary: () => ref.invalidate(staffAccessProvider),
      ),
      data: (a) => switch (a.kind) {
        StaffAccessKind.approved => PortalShell(me: a.me!),
        StaffAccessKind.needsHospital => a.me!.isAdmin
            ? const HospitalFormScreen()
            : AccessStateScreen(
                icon: Icons.local_hospital_outlined,
                tone: StaffTone.amber,
                title: 'No hospital linked',
                message: 'Your account is approved but not linked to a hospital yet. '
                    'Ask your hospital administrator to add you.',
                primaryLabel: 'Check again',
                onPrimary: () => ref.invalidate(staffAccessProvider),
              ),
        StaffAccessKind.pending => PendingApprovalScreen(me: a.me!),
        StaffAccessKind.rejected => AccessStateScreen(
            icon: Icons.block_rounded,
            tone: StaffTone.danger,
            title: 'Access request declined',
            message: 'Your hospital administrator did not approve this staff account. '
                'If you think this is a mistake, contact them and request access again.',
            note: a.me?.reviewNote,
            primaryLabel: 'Request access again',
            onPrimary: () => context.go('/login/hospital_personnel'),
          ),
        StaffAccessKind.suspended => AccessStateScreen(
            icon: Icons.pause_circle_outline_rounded,
            tone: StaffTone.amber,
            title: 'Account suspended',
            message: 'Your portal access has been suspended by your hospital administrator. '
                'Contact them to have it restored.',
            note: a.me?.reviewNote,
          ),
        StaffAccessKind.none => AccessStateScreen(
            icon: Icons.badge_outlined,
            tone: StaffTone.brand,
            title: 'No staff account',
            message: 'This sign-in has no hospital staff account. Request access to join your hospital.',
            primaryLabel: 'Request staff access',
            onPrimary: () => context.go('/login/hospital_personnel'),
          ),
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.staffNavy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const VitaNetLogo(size: 48),
              const SizedBox(height: 20),
              Semantics(
                label: 'Checking your access',
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.mintLight),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Full-screen explanation for an access state, with sign out.
class AccessStateScreen extends ConsumerWidget {
  final IconData icon;
  final StaffTone tone;
  final String title;
  final String message;
  final String? note;
  final List<Widget> details;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;

  const AccessStateScreen({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    this.note,
    this.details = const [],
    this.primaryLabel,
    this.onPrimary,
    this.primaryLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = StaffPalette.of(context);
    final t = p.tone(tone);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: StaffContent(
                maxWidth: 440,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: VitaNetLogo(size: 40)),
                    const SizedBox(height: 24),
                    StaffCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(16)),
                            child: Icon(icon, color: t.strong, size: 26),
                          ),
                          const SizedBox(height: 16),
                          Semantics(header: true, child: Text(title, style: staffHeading(22, color: p.ink))),
                          const SizedBox(height: 8),
                          Text(message, style: staffBody(14, color: p.inkSoft, height: 1.5)),
                          if ((note ?? '').isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(12)),
                              child: Text('Note from administrator: $note',
                                  style: staffBody(13, color: p.body, height: 1.45)),
                            ),
                          ],
                          ...details,
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (primaryLabel != null) ...[
                      StaffButton(primaryLabel!, loading: primaryLoading, onPressed: onPrimary),
                      const SizedBox(height: 10),
                    ],
                    StaffButton('Sign out',
                        kind: StaffButtonKind.secondary,
                        icon: Icons.logout_rounded,
                        onPressed: () => confirmAndSignOut(context, ref)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Waiting for approval" — shows the hospital chosen; refresh re-checks
/// GET /staff/me.
class PendingApprovalScreen extends ConsumerWidget {
  final StaffMe me;
  const PendingApprovalScreen({super.key, required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = StaffPalette.of(context);
    final facilities = ref.watch(facilitiesProvider);
    final hospitalName = facilities.whenOrNull(
      data: (list) => list.where((f) => f.id == me.hospitalId).map((f) => f.name).firstOrNull,
    );
    final refreshing = ref.watch(staffAccessProvider).isLoading;
    return AccessStateScreen(
      icon: Icons.hourglass_top_rounded,
      tone: StaffTone.amber,
      title: 'Waiting for approval',
      message: 'Your request has been sent. A hospital administrator needs to approve your '
          'account before you can use the portal.',
      note: me.reviewNote,
      details: [
        const SizedBox(height: 16),
        Divider(color: p.divider, height: 1),
        const SizedBox(height: 6),
        InfoRow('Hospital', hospitalName ?? (me.hospitalId == null ? 'Not chosen' : 'Loading…')),
        InfoRow('Name', me.fullName),
        InfoRow('Role', me.role.label),
        if ((me.department ?? '').isNotEmpty) InfoRow('Department', me.department!),
      ],
      primaryLabel: 'Check again',
      primaryLoading: refreshing,
      onPrimary: () => ref.invalidate(staffAccessProvider),
    );
  }
}

/// "End your session?" (design): warns about patients still assigned.
class _EndSessionDialog extends StatelessWidget {
  final int assigned;
  const _EndSessionDialog({required this.assigned});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final amber = p.tone(StaffTone.amber);
    final patients = assigned == 1 ? '1 patient' : '$assigned patients';
    return Dialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: p.tone(StaffTone.neutral).bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.logout_rounded, color: p.body, size: 26),
              ),
            ),
            const SizedBox(height: 16),
            Text('End your session?', textAlign: TextAlign.center, style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 10),
            Text(
              assigned > 0
                  ? "You're signing out of the clinical system on this device. You have $patients still assigned to you."
                  : "You're signing out of the clinical system on this device.",
              textAlign: TextAlign.center,
              style: staffBody(14, color: p.body, height: 1.5),
            ),
            if (assigned > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: amber.bg, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: amber.fg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Hand them over before leaving your shift.',
                          style: staffBody(13, weight: FontWeight.w600, color: amber.fg)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (assigned > 0) ...[
              StaffButton('Hand over patients first',
                  height: 52, radius: 16, onPressed: () => Navigator.of(context).pop(false)),
              const SizedBox(height: 10),
            ],
            StaffButton(assigned > 0 ? 'Sign out anyway' : 'Sign out',
                kind: StaffButtonKind.dangerOutline,
                height: 52,
                radius: 16,
                onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text('Cancel', style: staffBody(14, weight: FontWeight.w600, color: p.body)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}