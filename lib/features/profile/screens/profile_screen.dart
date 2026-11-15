import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/utils/profile_image.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref, UserProfile? profile) async {
    if (profile == null) {
      context.showSnack('Finish setting up your profile first');
      return;
    }
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) {
        await ref
            .read(userProfileProvider.notifier)
            .updateProfile(profile.copyWith(profileImagePath: image.path));
      }
    } catch (e) {
      if (context.mounted) context.showSnack('Could not open photos: $e');
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierColor: const Color(0x990F172A),
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnDialog(
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.logout_rounded, color: p.ink),
              ),
            ),
            Center(
              child: Text(
                'Sign out of VitaNet?',
                textAlign: TextAlign.center,
                style: VnText.heading(20, color: p.ink),
              ),
            ),
            Text(
              'Your checks stay saved to your account. You will need to sign in again to see them on this device.',
              textAlign: TextAlign.center,
              style: VnText.body(14, color: p.inkSoft, height: 1.55),
            ),
            VnButton(
              label: 'Sign out',
              height: 50,
              radius: 14,
              fontSize: 15,
              background: const Color(0xFFB91C1C),
              foreground: Colors.white,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            VnOutlineButton(
              label: 'Cancel',
              height: 44,
              borderColor: Colors.transparent,
              foreground: p.inkSoft,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await ref.read(userProfileProvider.notifier).clearProfile();
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final profile = ref.watch(userProfileProvider);
    final auth = ref.watch(authProvider);
    final history = ref.watch(triageHistoryProvider);
    final deviceCount = ref.watch(liveVitalsProvider).isNotEmpty ? 1 : 0;

    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : (auth.user?.displayName ?? 'Guest User');
    final email = auth.user?.email ?? (auth.status == AuthStatus.anonymous ? 'Guest session' : '');
    final metaItems = [
      if (profile?.age != null) '${profile!.age} yrs',
      if (profile?.sex != null && profile!.sex!.isNotEmpty) profile.sex!,
      if (profile?.bloodType != null && profile!.bloodType!.isNotEmpty) profile.bloodType!,
    ];
    final image = profileImageProvider(profile?.profileImagePath) ??
        (auth.user?.photoURL != null ? NetworkImage(auth.user!.photoURL!) : null);

    // Menu options matching approved design
    final menu = <(String, String, IconData, Color, Color, VoidCallback)>[
      (
        'Update medical info',
        'Blood type, allergies, conditions, medications',
        Icons.note_add_outlined,
        const Color(0xFFCCFBF1),
        const Color(0xFF0F766E),
        () => context.push('/edit-profile?tab=medical'),
      ),
      (
        'Check history',
        'All your past triage results',
        Icons.history_rounded,
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
        () => context.push('/history'),
      ),
      (
        'Devices & data',
        'Watch, Health Connect, permissions',
        Icons.watch_outlined,
        const Color(0xFFE0E7FF),
        const Color(0xFF4338CA),
        () => context.push('/device-connection/heart_rate'),
      ),
      (
        'App settings',
        'Notifications, appearance and privacy',
        Icons.tune_rounded,
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
        () => context.push('/settings'),
      ),
      (
        'Help center',
        'FAQs, guides and contact support',
        Icons.help_outline_rounded,
        const Color(0xFFE0F2FE),
        const Color(0xFF0369A1),
        () => context.push('/help-center'),
      ),
      (
        'About VitaNet',
        'Version, disclaimers and team',
        Icons.info_outline_rounded,
        const Color(0xFFEDE9FE),
        const Color(0xFF6D28D9),
        () => context.push('/about'),
      ),
    ];

    Widget statTile({
      required String value,
      required String label,
      required IconData icon,
      required Color accentColor,
      required VoidCallback onTap,
    }) =>
        Expanded(
          child: VnCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: onTap,
            semanticLabel: '$value $label',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(value, style: VnText.heading(22, color: p.ink)),
                    Icon(icon, size: 18, color: accentColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VnText.body(12, weight: FontWeight.w600, color: p.muted),
                ),
              ],
            ),
          ),
        );

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const VnAlwaysScrollablePhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              children: [
                // Top App Bar
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('Profile', style: VnText.heading(28, color: p.ink)),
                        ),
                      ),
                      VnIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        bordered: true,
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // User Identity Card
                VnCard(
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Avatar with edit photo button
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            VnAvatar(name: name, size: 72, fontSize: 24, image: image),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Semantics(
                                button: true,
                                label: 'Change photo',
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _pickPhoto(context, ref, profile),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: p.brand,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: p.surface, width: 2.5),
                                    ),
                                    child: Icon(Icons.camera_alt_rounded, size: 14, color: p.onBrand),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name, email, and demographics
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VnText.heading(20, color: p.ink),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VnText.body(13, color: p.muted),
                              ),
                            ],
                            if (metaItems.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final item in metaItems)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: p.surfaceAlt,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: p.line),
                                      ),
                                      child: Text(
                                        item,
                                        style: VnText.body(11, weight: FontWeight.w600, color: p.ink),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Quick Edit Personal Info
                      VnIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit personal details',
                        size: 38,
                        iconSize: 18,
                        bordered: true,
                        onPressed: () => context.push('/edit-profile?tab=personal'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Clean, Light Medical ID Card (Replaced the harsh black card)
                _MedicalIdCard(profile: profile),
                const SizedBox(height: 18),

                // 3 Stats Tiles
                Row(
                  children: [
                    statTile(
                      value: '${history.length}',
                      label: 'Checks',
                      icon: Icons.assignment_turned_in_outlined,
                      accentColor: const Color(0xFFD97706),
                      onTap: () => context.push('/history'),
                    ),
                    const SizedBox(width: 10),
                    statTile(
                      value: '${profile?.emergencyContacts.length ?? 0}',
                      label: 'Care circle',
                      icon: Icons.people_outline_rounded,
                      accentColor: const Color(0xFF6366F1),
                      onTap: () => context.push('/edit-profile?tab=emergency'),
                    ),
                    const SizedBox(width: 10),
                    statTile(
                      value: '$deviceCount',
                      label: deviceCount == 1 ? 'Device' : 'Devices',
                      icon: Icons.watch_outlined,
                      accentColor: const Color(0xFF0F766E),
                      onTap: () => context.push('/device-connection/heart_rate'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Settings & Options List
                VnListGroup(
                  radius: 20,
                  children: [
                    for (final (title, sub, icon, bg, fg, onTap) in menu)
                      VnListRow(
                        leading: VnIconTile(icon: icon, bg: bg, fg: fg, size: 40),
                        title: title,
                        subtitle: sub,
                        onTap: onTap,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Sign Out Button
                VnOutlineButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  background: p.surface,
                  borderColor: p.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                  foreground: p.danger,
                  onPressed: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clean, elevated light clinical "Medical ID" summary card.
class _MedicalIdCard extends StatelessWidget {
  final UserProfile? profile;
  const _MedicalIdCard({required this.profile});

  String _formatNumber(double? v, String unit) {
    if (v == null) return '--';
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final pr = profile;

    final bloodType = (pr?.bloodType?.isNotEmpty ?? false) ? pr!.bloodType! : '--';
    final heightStr = _formatNumber(pr?.height, 'cm');
    final weightStr = _formatNumber(pr?.weight, 'kg');

    final allergies = pr?.allergies.where((a) => a.trim().isNotEmpty).toList() ?? [];
    final conditions = pr?.preExistingConditions.where((c) => c.trim().isNotEmpty).toList() ?? [];
    final medications = pr?.medications.where((m) => m.trim().isNotEmpty).toList() ?? [];

    return VnCard(
      radius: 20,
      padding: EdgeInsets.zero,
      borderColor: p.line,
      onTap: () => context.push('/edit-profile?tab=medical'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Medical Shield Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.isDark ? const Color(0xFF3B1414) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    size: 22,
                    color: p.isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Medical ID', style: VnText.heading(17, color: p.ink)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.isDark ? const Color(0xFF0F2A27) : const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: p.isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                              ),
                            ),
                            child: Text(
                              'Emergency',
                              style: VnText.body(10, weight: FontWeight.w700, color: p.brand),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shown on lock screen',
                        style: VnText.body(12, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: p.muted),
              ],
            ),
          ),

          // Vitals / Body Measurements Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  // Blood Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blood type', style: VnText.body(11, weight: FontWeight.w600, color: p.muted)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.water_drop_rounded, size: 14, color: p.danger),
                            const SizedBox(width: 3),
                            Text(
                              bloodType,
                              style: VnText.heading(18, color: bloodType != '--' ? p.danger : p.ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: p.line),
                  // Height
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Height', style: VnText.body(11, weight: FontWeight.w600, color: p.muted)),
                          const SizedBox(height: 2),
                          Text(heightStr, style: VnText.heading(18, color: p.ink)),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 32, color: p.line),
                  // Weight
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weight', style: VnText.body(11, weight: FontWeight.w600, color: p.muted)),
                          const SizedBox(height: 2),
                          Text(weightStr, style: VnText.heading(18, color: p.ink)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Clinical Details: Allergies, Conditions, Medications
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Allergies
                _ClinicalRow(
                  label: 'Allergies',
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFDC2626),
                  items: allergies,
                  emptyText: 'No allergies recorded',
                  isWarning: true,
                ),
                const SizedBox(height: 10),
                // Conditions
                _ClinicalRow(
                  label: 'Conditions',
                  icon: Icons.favorite_border_rounded,
                  iconColor: const Color(0xFF0284C7),
                  items: conditions,
                  emptyText: 'None recorded',
                ),
                const SizedBox(height: 10),
                // Medications
                _ClinicalRow(
                  label: 'Medications',
                  icon: Icons.medication_outlined,
                  iconColor: const Color(0xFF0F766E),
                  items: medications,
                  emptyText: 'None recorded',
                  isTeal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tappable Footer to Edit
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: p.surfaceAlt.withValues(alpha: 0.6),
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 18, color: p.brand),
                const SizedBox(width: 6),
                Text(
                  'Tap to update medical info',
                  style: VnText.body(12, weight: FontWeight.w700, color: p.brand),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, size: 14, color: p.brand),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper row for displaying clinical tags or an empty state neatly.
class _ClinicalRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final List<String> items;
  final String emptyText;
  final bool isWarning;
  final bool isTeal;

  const _ClinicalRow({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.emptyText,
    this.isWarning = false,
    this.isTeal = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Text(label, style: VnText.body(11, weight: FontWeight.w700, color: p.muted)),
          ],
        ),
        const SizedBox(height: 5),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(emptyText, style: VnText.body(13, color: p.muted)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isWarning
                          ? (p.isDark ? const Color(0xFF3B1414) : const Color(0xFFFEF2F2))
                          : isTeal
                              ? (p.isDark ? const Color(0xFF0F2A27) : const Color(0xFFF0FDFA))
                              : p.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isWarning
                            ? (p.isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA))
                            : isTeal
                                ? (p.isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1))
                                : p.line,
                      ),
                    ),
                    child: Text(
                      item,
                      style: VnText.body(
                        12,
                        weight: FontWeight.w600,
                        color: isWarning
                            ? (p.isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C))
                            : isTeal
                                ? (p.isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E))
                                : p.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
