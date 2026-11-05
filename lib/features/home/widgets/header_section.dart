import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/home/screens/home_search_screen.dart';
import 'package:vitanet/features/notifications/screens/notifications_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Home header: avatar, date + greeting, notifications bell, then search bar.
class HeaderSection extends ConsumerWidget {
  const HeaderSection({super.key});

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _date() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeSearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final profile = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);
    final unread = ref.watch(notificationsUnreadProvider);
    final staffAccess = ref.watch(staffAccessProvider).valueOrNull;
    final fullName = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : (authState.user?.displayName ?? '');
    final firstName = fullName.isEmpty ? '' : fullName.split(RegExp(r'\s+')).first;
    final photo = authState.user?.photoURL;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Profile',
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => StatefulNavigationShell.of(context).goBranch(3),
                  child: VnAvatar(
                    name: fullName.isEmpty ? 'VitaNet' : fullName,
                    size: 48,
                    image: photo == null
                        ? null
                        : ResizeImage(NetworkImage(photo), width: 96, height: 96),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_date(), style: VnText.body(13, color: p.muted)),
                    Text(
                      firstName.isEmpty ? _greeting() : '${_greeting()}, $firstName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VnText.heading(20, color: p.ink),
                    ),
                  ],
                ),
              ),
              VnIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: unread ? 'Notifications, unread' : 'Notifications',
                size: 46,
                bordered: true,
                onPressed: () => context.push('/notifications'),
                badge: unread
                    ? Positioned(
                        top: 9,
                        right: 10,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                            border: Border.all(color: p.surface, width: 2),
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
        if (staffAccess?.isPortalUser == true) ...[
          const SizedBox(height: 14),
          Material(
            color: AppColors.staffNavy,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ref.read(activeWorkspaceProvider.notifier).setWorkspace(AppWorkspace.hospital);
                context.go('/admin');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0x1F2DD4BF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, size: 18, color: AppColors.mintLight),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hospital Portal · ${staffAccess!.me?.role.label ?? "Staff"} Workspace',
                            style: VnText.body(13, weight: FontWeight.w700, color: const Color(0xFFF1F5F9)),
                          ),
                          Text(
                            'Switch to clinical ER, triage & inpatient dashboard',
                            style: VnText.body(11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x2E2DD4BF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mintLight)),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.mintLight),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Hero(
          tag: 'home_search_bar',
          child: Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openSearch(context),
              child: Semantics(
                button: true,
                label: 'Search health, vitals, medicines',
                excludeSemantics: true,
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 20, color: p.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Search health, vitals, medicines…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VnText.body(15, color: p.muted)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Teal "Not feeling well?" call-to-action card.
class SymptomCheckHero extends StatelessWidget {
  const SymptomCheckHero({super.key});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.isDark ? const Color(0xFF0D5F58) : AppColors.brand,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08), width: 28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 16, color: Color(0xFF99F6E4)),
                    const SizedBox(width: 6),
                    Text('VITANET AI',
                        style: VnText.body(12,
                            weight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: const Color(0xFF99F6E4))),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    'Not feeling well? Check your symptoms in 2 minutes.',
                    style: VnText.heading(22, color: Colors.white, height: 1.3),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    VnButton(
                      label: 'Start a check',
                      icon: Icons.chat_bubble_outline_rounded,
                      height: 48,
                      radius: 14,
                      fontSize: 15,
                      expand: false,
                      background: Colors.white,
                      foreground: AppColors.brand,
                      onPressed: () => StatefulNavigationShell.of(context).goBranch(1),
                    ),
                    VnOutlineButton(
                      label: 'Guided form',
                      height: 48,
                      radius: 14,
                      expand: false,
                      background: Colors.white.withValues(alpha: 0.14),
                      borderColor: Colors.transparent,
                      foreground: Colors.white,
                      onPressed: () => context.push('/assessment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
