import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/alerts_screen.dart';
import 'package:vitanet/features/admin/screens/cases_screen.dart';
import 'package:vitanet/features/admin/screens/hospital_screen.dart';
import 'package:vitanet/features/admin/screens/portal_settings_screen.dart';
import 'package:vitanet/features/admin/screens/referrals_screen.dart';
import 'package:vitanet/features/admin/screens/team_screen.dart';
import 'package:vitanet/features/admin/screens/today_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';
import 'package:vitanet/shared/widgets/vitanet_logo.dart';

/// The signed-in, approved staff member (from GET /staff/me).
final portalMeProvider = Provider<StaffMe?>((ref) => ref.watch(staffAccessProvider).valueOrNull?.me);

enum PortalTab {
  today('Today', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  referrals('Referrals', Icons.move_to_inbox_outlined, Icons.move_to_inbox_rounded),
  cases('Cases', Icons.assignment_ind_outlined, Icons.assignment_ind_rounded),
  alerts('Alerts', Icons.notifications_none_rounded, Icons.notifications_rounded),
  hospital('Hospital', Icons.local_hospital_outlined, Icons.local_hospital_rounded),
  team('Team', Icons.groups_outlined, Icons.groups_rounded),
  settings('Settings', Icons.settings_outlined, Icons.settings_rounded);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  const PortalTab(this.label, this.icon, this.activeIcon);
}

/// Portal navigation: bottom bar (Today, Referrals, Cases, Alerts, More) on
/// phones, a side nav with every section on wide screens.
class PortalShell extends ConsumerStatefulWidget {
  final StaffMe me;
  const PortalShell({super.key, required this.me});

  @override
  ConsumerState<PortalShell> createState() => PortalShellState();
}

class PortalShellState extends ConsumerState<PortalShell> {
  PortalTab _tab = PortalTab.today;

  static const _phoneTabs = [PortalTab.today, PortalTab.referrals, PortalTab.cases, PortalTab.alerts];

  List<PortalTab> get _tabs =>
      [for (final t in PortalTab.values) if (t != PortalTab.team || widget.me.isAdmin) t];

  void select(PortalTab t) => setState(() => _tab = t);

  Widget _screen(PortalTab t, bool active, {VoidCallback? onBack}) => switch (t) {
        PortalTab.today => TodayScreen(active: active, onOpenTab: select),
        PortalTab.referrals => ReferralsScreen(active: active),
        PortalTab.cases => CasesScreen(active: active),
        PortalTab.alerts => AlertsScreen(active: active),
        PortalTab.hospital => HospitalScreen(onBack: onBack),
        PortalTab.team => TeamScreen(onBack: onBack),
        PortalTab.settings => PortalSettingsScreen(onBack: onBack),
      };

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final incoming = ref.watch(dashboardProvider).valueOrNull?.counts.incoming ?? 0;
    final alerts = ref.watch(alertsProvider).valueOrNull?.length ?? 0;
    String? badgeFor(PortalTab t) => switch (t) {
          PortalTab.referrals when incoming > 0 => '$incoming',
          PortalTab.alerts when alerts > 0 => '$alerts',
          _ => null,
        };

    // On phones, Hospital / Team / Settings live under "More".
    final phoneTab = _phoneTabs.contains(_tab) ? _tab : null;
    final shownTabs = wide ? _tabs : [..._phoneTabs, PortalTab.settings];
    final stack = IndexedStack(
      index: wide ? _tabs.indexOf(_tab).clamp(0, _tabs.length - 1) : (phoneTab == null ? 4 : _phoneTabs.indexOf(phoneTab)),
      children: [
        for (final t in (wide ? _tabs : _phoneTabs))
          TickerMode(enabled: t == _tab, child: _screen(t, t == _tab)),
        if (!wide) _MoreScreen(tabs: _tabs.where((t) => !_phoneTabs.contains(t)).toList(), screen: _screen),
      ],
    );

    final body = AutoRefresh(
      active: true,
      onTick: () {
        ref.invalidate(dashboardProvider);
        ref.invalidate(alertsProvider);
      },
      child: stack,
    );

    if (wide) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Row(
          children: [
            _SideNav(
              tabs: shownTabs,
              selected: _tab,
              me: widget.me,
              badgeFor: badgeFor,
              onSelect: select,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    final navIndex = phoneTab == null ? 4 : _phoneTabs.indexOf(phoneTab);
    return Scaffold(
      backgroundColor: p.bg,
      body: body,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: p.card,
          indicatorColor: p.tone(StaffTone.brand).bg,
          labelTextStyle: WidgetStateProperty.resolveWith((s) => staffBody(11,
              weight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
              color: s.contains(WidgetState.selected) ? p.accent : p.muted)),
          iconTheme: WidgetStateProperty.resolveWith(
              (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? p.accent : p.muted)),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: navIndex,
          onDestinationSelected: (i) => select(i < 4 ? _phoneTabs[i] : PortalTab.settings),
          destinations: [
            for (final t in _phoneTabs)
              NavigationDestination(
                icon: Badge(isLabelVisible: badgeFor(t) != null, label: Text(badgeFor(t) ?? ''), child: Icon(t.icon)),
                selectedIcon:
                    Badge(isLabelVisible: badgeFor(t) != null, label: Text(badgeFor(t) ?? ''), child: Icon(t.activeIcon)),
                label: t.label,
                tooltip: t.label,
              ),
            const NavigationDestination(
              icon: Icon(Icons.menu_rounded),
              selectedIcon: Icon(Icons.menu_open_rounded),
              label: 'More',
              tooltip: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreScreen extends ConsumerWidget {
  final List<PortalTab> tabs;
  final Widget Function(PortalTab, bool, {VoidCallback? onBack}) screen;
  const _MoreScreen({required this.tabs, required this.screen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = StaffPalette.of(context);
    final me = ref.watch(portalMeProvider);
    String sub(PortalTab t) => switch (t) {
          PortalTab.hospital => 'Wards, beds, equipment and who is on duty',
          PortalTab.team => 'Approve staff requests, roles and access',
          PortalTab.settings => 'Profile, facility, notifications, sign out',
          _ => '',
        };
    return Column(
      children: [
        PortalHeader(title: 'More', subtitle: me == null ? null : '${me.fullName} · ${me.role.label}'),
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: const EdgeInsets.all(16),
            children: [
              StaffContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaffGroup(children: [
                      for (final t in tabs)
                        StaffNavRow(
                          title: t.label,
                          subtitle: sub(t),
                          icon: t.icon,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (ctx) => Scaffold(
                              backgroundColor: p.bg,
                              body: screen(t, true, onBack: () => Navigator.of(ctx).pop()),
                            ),
                          )),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    StaffButton(
                      'Switch to Personal Health App',
                      kind: StaffButtonKind.secondary,
                      icon: Icons.person_rounded,
                      onPressed: () => context.go('/home?personal=1'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideNav extends StatelessWidget {
  final List<PortalTab> tabs;
  final PortalTab selected;
  final StaffMe me;
  final String? Function(PortalTab) badgeFor;
  final ValueChanged<PortalTab> onSelect;

  const _SideNav({
    required this.tabs,
    required this.selected,
    required this.me,
    required this.badgeFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: AppColors.staffNavy,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const VitaNetLogo(size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('VitaNet', style: staffHeading(18, color: Colors.white)),
                          Text('Hospital portal', style: staffBody(11, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              for (final t in tabs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Semantics(
                    button: true,
                    selected: t == selected,
                    label: badgeFor(t) == null ? t.label : '${t.label}, ${badgeFor(t)} new',
                    excludeSemantics: true,
                    child: Material(
                      color: t == selected ? const Color(0x1F2DD4BF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(t),
                        child: SizedBox(
                          height: 46,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(t == selected ? t.activeIcon : t.icon,
                                    size: 20, color: t == selected ? AppColors.mintLight : const Color(0xFF94A3B8)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(t.label,
                                      style: staffBody(14,
                                          weight: t == selected ? FontWeight.w700 : FontWeight.w500,
                                          color: t == selected ? Colors.white : const Color(0xFFCBD5E1))),
                                ),
                                if (badgeFor(t) != null)
                                  StaffTag(badgeFor(t)!, tone: StaffTone.danger, fontSize: 11),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: const Color(0x1A2DD4BF),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.go('/home?personal=1'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: const [
                          Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.mintLight),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Personal Health App',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.mintLight),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    StaffInitialsAvatar(initialsOf(me.fullName), tone: StaffTone.brand, size: 36, fontSize: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: staffBody(13, weight: FontWeight.w600, color: Colors.white)),
                          Text(me.role.label, style: staffBody(11, color: const Color(0xFF94A3B8))),
                        ],
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
}
