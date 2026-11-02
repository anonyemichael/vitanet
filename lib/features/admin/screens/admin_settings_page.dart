import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import '../widgets/staff_demo_data.dart';
import '../widgets/staff_ui.dart';
import 'admin_app_preferences_page.dart';
import 'admin_profile_settings_page.dart';
import 'admin_security_settings_page.dart';
import 'case_management_screen.dart';

/// Staff settings (AdminSettings.dc.html).
class AdminSettingsPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;
  final VoidCallback onNavigateToNotifications;

  const AdminSettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
    required this.onNavigateToNotifications,
  });

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _alertSound = true;
  bool _referrals = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _alertSound = prefs.getBool('staffCriticalAlertSound') ?? true;
      _referrals = prefs.getBool('staffIncomingReferrals') ?? true;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _handleLogout(BuildContext context) {
    final p = StaffPalette.of(context);
    showStaffDialog<void>(
      context,
      builder: (dialogContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.logout_rounded, size: 26, color: p.ink),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text('End your session?', textAlign: TextAlign.center, style: staffHeading(20, color: p.ink)),
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'You\'re signing out of the clinical system on this device. You have '),
                  TextSpan(text: '2 patients', style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
                  const TextSpan(text: ' still assigned to you.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: staffBody(14, color: p.inkSoft, height: 1.55),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.dark ? p.tone(StaffTone.amber).bg : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.dark ? const Color(0x66F59E0B) : const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: p.dark ? p.tone(StaffTone.amber).fg : kStaffAmber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hand them over before leaving your shift.',
                      style: staffBody(13, color: p.dark ? p.tone(StaffTone.amber).fg : const Color(0xFF78350F)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            StaffButton(
              'Hand over patients first',
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaseManagementScreen()));
              },
            ),
            const SizedBox(height: 10),
            StaffButton(
              'Sign out anyway',
              kind: StaffButtonKind.dangerOutline,
              onPressed: () async {
                Navigator.pop(dialogContext); // Close the dialog
                if (Firebase.apps.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                }
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 10),
            StaffButton(
              'Cancel',
              kind: StaffButtonKind.ghost,
              height: 44,
              fontSize: 14,
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSupport(BuildContext context) {
    final p = StaffPalette.of(context);
    showStaffDialog<void>(
      context,
      builder: (dialogContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: p.tone(StaffTone.brand).bg, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.support_agent_rounded, size: 26, color: p.accent),
              ),
            ),
            const SizedBox(height: 14),
            Text('Clinical support', style: staffHeading(20, color: p.ink)),
            const SizedBox(height: 8),
            Text(
              'For urgent technical issues, contact the clinical IT desk at ext. 555 or email support@korlebu.gov.gh. The desk is staffed 24 hours.',
              style: staffBody(13, color: p.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StaffButton('Dismiss',
                      kind: StaffButtonKind.secondary, onPressed: () => Navigator.pop(dialogContext)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StaffButton(
                    'Call ext. 555',
                    icon: Icons.call_outlined,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      LaunchHelpers.dialOrSnack(context, '555');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final user = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
    final displayName =
        (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName!.trim() : kDemoStaffName;
    final isDarkMode = widget.currentThemeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            StaffContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Semantics(header: true, child: Text('Settings', style: staffHeading(24, color: p.ink))),
                  ),
                  const SizedBox(height: 16),
                  // Navy profile card
                  Semantics(
                    button: true,
                    label: 'Profile, $displayName, verified',
                    excludeSemantics: true,
                    child: Material(
                      color: AppColors.staffNavy,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminProfileSettingsPage()),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const StaffPhoto(kStaffPhoto, size: 56, radius: 16),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: staffBody(16, weight: FontWeight.w700, color: const Color(0xFFF1F5F9)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'MDC/RN/04712 · Emergency physician',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: staffBody(12, color: const Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0x262DD4BF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Verified',
                                  style: staffBody(11, weight: FontWeight.w700, color: AppColors.mintLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Account'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      StaffNavRow(
                        title: 'Profile & credentials',
                        subtitle: 'License, department, contact',
                        icon: Icons.person_outline_rounded,
                        iconTone: StaffTone.indigo,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminProfileSettingsPage()),
                        ),
                      ),
                      StaffNavRow(
                        title: 'Security & access key',
                        subtitle: 'Last changed 42 days ago',
                        icon: Icons.key_outlined,
                        iconTone: StaffTone.amber,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminSecuritySettingsPage()),
                        ),
                      ),
                      StaffNavRow(
                        title: 'Notifications',
                        subtitle: 'Alerts, referrals, handovers',
                        icon: Icons.notifications_none_rounded,
                        iconTone: StaffTone.brand,
                        onTap: widget.onNavigateToNotifications,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('App preferences'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      StaffSwitchRow(
                        title: 'Critical alert sound',
                        subtitle: 'Plays even on silent',
                        value: _alertSound,
                        onChanged: (v) {
                          setState(() => _alertSound = v);
                          _setPref('staffCriticalAlertSound', v);
                        },
                      ),
                      StaffSwitchRow(
                        title: 'Incoming VitaNet referrals',
                        subtitle: 'Urgent and doctor-level only',
                        value: _referrals,
                        onChanged: (v) {
                          setState(() => _referrals = v);
                          _setPref('staffIncomingReferrals', v);
                        },
                      ),
                      StaffSwitchRow(
                        title: 'Dark mode for night shifts',
                        subtitle: 'Auto 19:00–07:00',
                        value: isDarkMode,
                        onChanged: (v) => widget.onThemeChanged(v ? ThemeMode.dark : ThemeMode.light),
                      ),
                      StaffNavRow(
                        title: 'Display & accessibility',
                        subtitle: 'Theme, contrast, language',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminAppPreferencesPage(
                              onThemeChanged: widget.onThemeChanged,
                              currentThemeMode: widget.currentThemeMode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Support'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      StaffNavRow(
                        title: 'Clinical IT support',
                        subtitle: 'Ext. 555 · support@korlebu.gov.gh',
                        onTap: () => _handleSupport(context),
                      ),
                      StaffNavRow(
                        title: 'Clinical use policy',
                        onTap: () => context.push('/disclaimer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StaffButton(
                    'Terminate session',
                    icon: Icons.logout_rounded,
                    kind: StaffButtonKind.dangerOutline,
                    height: 52,
                    radius: 16,
                    onPressed: () => _handleLogout(context),
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
