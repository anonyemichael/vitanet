import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vitanet/core/constants/app_strings.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/settings/settings_providers.dart';
import 'package:vitanet/features/settings/widgets/settings_dialogs.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _toggles = <(String, String, String)>[
    ('urgent_alerts', 'Urgent health alerts', 'Low SpO2, heart rate spikes'),
    ('medication_reminders', 'Medication reminders', 'At the times you set'),
    ('weekly_summary', 'Weekly wellness summary', 'Sunday mornings'),
    ('care_circle_activity', 'Care circle activity', 'When contacts accept or respond'),
  ];

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System default',
      };

  void _exportData(UserProfile? profile, List<TriageResult> history) {
    final b = StringBuffer('VitaNet health summary\n\n');
    if (profile != null) {
      b.writeln('Name: ${profile.name}');
      if (profile.age != null) b.writeln('Age: ${profile.age}');
      if (profile.sex != null) b.writeln('Sex: ${profile.sex}');
      if (profile.bloodType != null) b.writeln('Blood type: ${profile.bloodType}');
      if (profile.height != null) b.writeln('Height: ${profile.height} cm');
      if (profile.weight != null) b.writeln('Weight: ${profile.weight} kg');
      if (profile.allergies.isNotEmpty) b.writeln('Allergies: ${profile.allergies.join(', ')}');
      if (profile.preExistingConditions.isNotEmpty) {
        b.writeln('Conditions: ${profile.preExistingConditions.join(', ')}');
      }
      if (profile.medications.isNotEmpty) b.writeln('Medications: ${profile.medications.join(', ')}');
      b.writeln();
    }
    b.writeln('Past checks (${history.length}):');
    for (final h in history) {
      final d = h.timestamp;
      b.writeln('- ${d.day}/${d.month}/${d.year}: ${h.primarySymptom} (${h.level.name})');
    }
    b
      ..writeln()
      ..writeln(AppStrings.disclaimer);
    Share.share(b.toString(), subject: 'VitaNet health summary');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final currentTheme = ref.watch(themeModeProvider);
    final textScale = ref.watch(textScaleProvider);
    final notif = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                VnTopBar(
                  title: 'Settings',
                  onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
                ),
                const SizedBox(height: 18),
                const VnSectionLabel('Appearance'),
                const SizedBox(height: 8),
                VnListGroup(children: [
                  VnListRow(
                    leading: const VnIconTile(
                        icon: Icons.dark_mode_outlined, bg: Color(0xFFE0E7FF), fg: Color(0xFF4338CA)),
                    title: 'Theme',
                    value: _themeLabel(currentTheme),
                    onTap: () => showThemeSheet(context),
                  ),
                  VnListRow(
                    leading: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Aa',
                          style: VnText.body(14, weight: FontWeight.w800, color: p.inkSoft)),
                    ),
                    title: 'Text size',
                    value: TextScaleNotifier.labelFor(textScale),
                    onTap: () => showTextSizeSheet(context),
                  ),
                  const VnListRow(
                    leading: VnIconTile(
                        icon: Icons.language_rounded, bg: Color(0xFFD1FAE5), fg: Color(0xFF047857)),
                    title: 'Language',
                    value: 'English',
                    chevron: false,
                  ),
                ]),
                const SizedBox(height: 18),
                const VnSectionLabel('Notifications'),
                const SizedBox(height: 8),
                VnListGroup(children: [
                  for (final (key, title, sub) in _toggles)
                    VnListRow(
                      title: title,
                      subtitle: sub,
                      chevron: false,
                      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                      onTap: () => ref
                          .read(notificationPrefsProvider.notifier)
                          .toggle(key, !(notif[key] ?? false)),
                      trailing: VnSwitch(
                        value: notif[key] ?? false,
                        semanticLabel: title,
                        onChanged: (v) =>
                            ref.read(notificationPrefsProvider.notifier).toggle(key, v),
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                const VnSectionLabel('Privacy & data'),
                const SizedBox(height: 8),
                VnListGroup(children: [
                  VnListRow(
                    leading: const VnIconTile(
                        icon: Icons.download_rounded, bg: Color(0xFFE0F2FE), fg: Color(0xFF0369A1)),
                    title: 'Export my health data',
                    subtitle: 'Summary to share with your doctor',
                    onTap: () => _exportData(
                        ref.read(userProfileProvider), ref.read(triageHistoryProvider)),
                  ),
                  VnListRow(
                    leading: const VnIconTile(
                        icon: Icons.delete_outline_rounded,
                        bg: Color(0xFFFEE2E2),
                        fg: Color(0xFFB91C1C)),
                    title: 'Clear triage history',
                    titleColor: p.danger,
                    subtitle: 'Permanently delete past AI checks',
                    onTap: () => showClearHistoryDialog(context),
                  ),
                  VnListRow(
                    leading: VnIconTile(
                        icon: Icons.shield_outlined, bg: const Color(0xFFF1F5F9), fg: p.isDark ? p.inkSoft : const Color(0xFF334155)),
                    title: 'Privacy policy',
                    subtitle: 'HIPAA and GDPR-aligned handling',
                    onTap: () => context.push('/privacy'),
                  ),
                ]),
                const SizedBox(height: 18),
                const VnSectionLabel('About'),
                const SizedBox(height: 8),
                VnListGroup(children: [
                  VnListRow(title: 'About VitaNet', onTap: () => context.push('/about')),
                  VnListRow(title: 'Medical disclaimer', onTap: () => context.push('/disclaimer')),
                  VnListRow(title: 'Help center', onTap: () => context.push('/help-center')),
                ]),
                const SizedBox(height: 18),
                Text('VitaNet 1.0.0',
                    textAlign: TextAlign.center, style: VnText.body(12, color: p.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
