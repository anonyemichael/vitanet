import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/admin/screens/admin_home_page.dart';
import 'package:vitanet/features/admin/screens/admin_notifications_page.dart';
import 'package:vitanet/features/admin/screens/admin_patient_data_page.dart';
import 'package:vitanet/features/admin/screens/admin_infrastructure_page.dart';
import 'package:vitanet/features/admin/screens/admin_settings_page.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

class AdminMainNavigationScreen extends ConsumerStatefulWidget {
  const AdminMainNavigationScreen({super.key});

  @override
  ConsumerState<AdminMainNavigationScreen> createState() => _AdminMainNavigationScreenState();
}

class _AdminMainNavigationScreenState extends ConsumerState<AdminMainNavigationScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final p = StaffPalette.of(context);

    final pages = <Widget>[
      AdminHomePage(
        onOpenAlerts: () => _onItemTapped(1),
        onOpenHospital: () => _onItemTapped(3),
      ),
      const AdminNotificationsPage(),
      const AdminPatientDataPage(),
      const AdminInfrastructurePage(),
      AdminSettingsPage(
        onThemeChanged: (mode) => ref.read(themeModeProvider.notifier).setTheme(mode),
        currentThemeMode: themeMode,
        onNavigateToNotifications: () => _onItemTapped(1),
      ),
    ];

    return Scaffold(
      backgroundColor: p.bg,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: StaffBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _onItemTapped,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem(Icons.notifications_none_rounded, Icons.notifications_rounded, 'Alerts'),
  _NavItem(Icons.people_outline_rounded, Icons.people_rounded, 'Patients'),
  _NavItem(Icons.local_hospital_outlined, Icons.local_hospital_rounded, 'Hospital'),
  _NavItem(Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
];

/// Staff portal bottom navigation: white bar, active item in a mint pill.
class StaffBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const StaffBottomNav({super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final brand = p.tone(StaffTone.brand);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          container: true,
          label: 'Staff navigation',
          child: SizedBox(
            height: 66,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == selectedIndex,
                            button: true,
                            label: _items[i].label,
                            excludeSemantics: true,
                            child: InkWell(
                              onTap: () => onSelected(i),
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: i == selectedIndex ? brand.bg : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Icon(
                                      i == selectedIndex ? _items[i].activeIcon : _items[i].icon,
                                      size: 20,
                                      color: i == selectedIndex ? p.accent : p.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _items[i].label,
                                    maxLines: 1,
                                    style: staffBody(
                                      11,
                                      weight: i == selectedIndex ? FontWeight.w700 : FontWeight.w600,
                                      color: i == selectedIndex ? p.accent : p.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
