import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vitanet/core/constants/app_colors.dart';
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
              child: Text('Sign out of VitaNet?',
                  textAlign: TextAlign.center, style: VnText.heading(20, color: p.ink)),
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
    final devices = ref.watch(deviceConnectionProvider).maybeWhen(
          data: (m) => m.values.where((v) => v).length,
          orElse: () => 0,
        );
    final liveCount = ref.watch(liveVitalsProvider).isNotEmpty ? 1 : 0;
    final deviceCount = devices > 0 ? devices : liveCount;

    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : (auth.user?.displayName ?? 'Guest');
    final email = auth.user?.email ?? (auth.status == AuthStatus.anonymous ? 'Guest session' : '');
    final meta = [
      if (profile?.age != null) '${profile!.age}',
      if (profile?.sex != null && profile!.sex!.isNotEmpty) profile.sex!,
      if (profile?.bloodType != null && profile!.bloodType!.isNotEmpty) profile.bloodType!,
    ].join(' · ');
    final image = profileImageProvider(profile?.profileImagePath) ??
        (auth.user?.photoURL != null ? NetworkImage(auth.user!.photoURL!) : null);

    final menu = <(String, String, IconData, Color, Color, VoidCallback)>[
      ('Update medical info', 'Blood type, allergies, conditions, medications',
          Icons.note_add_outlined, const Color(0xFFCCFBF1), const Color(0xFF0F766E),
          () => context.push('/edit-profile?tab=medical')),
      ('Check history', 'All your past triage results', Icons.history_rounded,
          const Color(0xFFFEF3C7), const Color(0xFFB45309), () => context.push('/history')),
      ('Devices & data', 'Watch, Health Connect, permissions', Icons.watch_outlined,
          const Color(0xFFE0E7FF), const Color(0xFF4338CA),
          () => context.push('/device-connection/heart_rate')),
      ('App settings', 'Notifications, appearance and privacy', Icons.tune_rounded,
          const Color(0xFFF1F5F9), const Color(0xFF334155), () => context.push('/settings')),
      ('Help center', 'FAQs, guides and contact support', Icons.help_outline_rounded,
          const Color(0xFFE0F2FE), const Color(0xFF0369A1), () => context.push('/help-center')),
      ('About VitaNet', 'Version, disclaimers and team', Icons.info_outline_rounded,
          const Color(0xFFF5F3FF), const Color(0xFF6D28D9), () => context.push('/about')),
    ];

    Widget statTile(String value, String label, VoidCallback onTap) => Expanded(
          child: VnCard(
            radius: 18,
            padding: const EdgeInsets.all(14),
            onTap: onTap,
            semanticLabel: '$value $label',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: VnText.body(22, weight: FontWeight.w800, color: p.ink)),
                const SizedBox(height: 2),
                Text(label, style: VnText.body(12, weight: FontWeight.w600, color: p.muted)),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              children: [
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          VnAvatar(name: name, size: 76, fontSize: 26, image: image),
                          Positioned(
                            right: -8,
                            bottom: -8,
                            child: Semantics(
                              button: true,
                              label: 'Change photo',
                              excludeSemantics: true,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _pickPhoto(context, ref, profile),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: p.brand,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: p.page, width: 3),
                                      ),
                                      child: Icon(Icons.edit_rounded, size: 13, color: p.onBrand),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VnText.heading(20, color: p.ink)),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VnText.body(14, color: p.muted)),
                          ],
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(meta, style: VnText.body(13, color: p.muted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _MedicalIdCard(profile: profile),
                const SizedBox(height: 18),
                Row(
                  children: [
                    statTile('${history.length}', 'Checks', () => context.push('/history')),
                    const SizedBox(width: 10),
                    statTile('${profile?.emergencyContacts.length ?? 0}', 'Care circle',
                        () => context.push('/edit-profile?tab=emergency')),
                    const SizedBox(width: 10),
                    statTile('$deviceCount', deviceCount == 1 ? 'Device' : 'Devices',
                        () => context.push('/device-connection/heart_rate')),
                  ],
                ),
                const SizedBox(height: 18),
                VnListGroup(
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
                const SizedBox(height: 18),
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

/// Dark "Medical ID" summary card.
class _MedicalIdCard extends StatelessWidget {
  final UserProfile? profile;
  const _MedicalIdCard({required this.profile});

  String _num(double? v, String unit) {
    if (v == null) return '--';
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final pr = profile;
    const label = Color(0xFF94A3B8);

    Widget field(String k, String v) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k, style: VnText.body(11, weight: FontWeight.w600, color: label)),
              const SizedBox(height: 2),
              Text(v, style: VnText.body(18, weight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        );

    Widget line(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$k ', style: VnText.body(13, color: label)),
              TextSpan(
                  text: v,
                  style: VnText.body(13, weight: FontWeight.w700, color: color ?? Colors.white)),
            ]),
          ),
        );

    String list(List<String>? l) => (l == null || l.isEmpty) ? 'None recorded' : l.join(', ');

    return Material(
      color: p.isDark ? const Color(0xFF0B1220) : AppColors.ink,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/edit-profile?tab=medical'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_information_outlined, size: 18, color: Color(0xFFFCA5A5)),
                  const SizedBox(width: 8),
                  Text('Medical ID',
                      style: VnText.body(14, weight: FontWeight.w700, color: const Color(0xFFFCA5A5))),
                  const Spacer(),
                  Text('Tap to edit', style: VnText.body(12, color: label)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  field('Blood type', (pr?.bloodType?.isNotEmpty ?? false) ? pr!.bloodType! : '--'),
                  const SizedBox(width: 10),
                  field('Height', _num(pr?.height, 'cm')),
                  const SizedBox(width: 10),
                  field('Weight', _num(pr?.weight, 'kg')),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 6),
              line('Allergies', list(pr?.allergies),
                  color: (pr?.allergies.isNotEmpty ?? false) ? const Color(0xFFFCA5A5) : null),
              line('Conditions', list(pr?.preExistingConditions)),
              line('Medications', list(pr?.medications)),
            ],
          ),
        ),
      ),
    );
  }
}
