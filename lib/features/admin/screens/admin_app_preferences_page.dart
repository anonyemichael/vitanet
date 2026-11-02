import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/staff_ui.dart';

/// Display & accessibility preferences, in the staff portal visual language.
class AdminAppPreferencesPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const AdminAppPreferencesPage({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<AdminAppPreferencesPage> createState() => _AdminAppPreferencesPageState();
}

class _AdminAppPreferencesPageState extends State<AdminAppPreferencesPage> {
  bool _highContrast = false;
  String _language = 'English';
  late ThemeMode _mode = widget.currentThemeMode;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _highContrast = prefs.getBool('highContrast') ?? false;
      _language = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _setHighContrast(bool value) async {
    setState(() => _highContrast = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highContrast', value);
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _mode = mode);
    widget.onThemeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            StaffContent(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaffPageHeader(
                    title: 'Display & accessibility',
                    fontSize: 21,
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Theme'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      _themeOption('Match device', 'Follows the system setting', ThemeMode.system,
                          Icons.brightness_auto_outlined),
                      _themeOption('Light', 'Best for bright wards', ThemeMode.light, Icons.light_mode_outlined),
                      _themeOption('Dark', 'Easier on the eyes on night shifts', ThemeMode.dark,
                          Icons.dark_mode_outlined),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Accessibility'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      StaffSwitchRow(
                        title: 'High contrast mode',
                        subtitle: 'Enhanced visibility for clinical data',
                        icon: Icons.contrast_rounded,
                        iconTone: StaffTone.indigo,
                        value: _highContrast,
                        onChanged: _setHighContrast,
                      ),
                      StaffNavRow(
                        title: 'System language',
                        subtitle: '$_language · set by your facility',
                        icon: Icons.translate_rounded,
                        iconTone: StaffTone.sky,
                        onTap: () => showStaffSnack(context, 'Language selection is locked by your organisation.'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(String label, String sub, ThemeMode mode, IconData icon) {
    final p = StaffPalette.of(context);
    final selected = _mode == mode;
    final brand = p.tone(StaffTone.brand);
    return Semantics(
      selected: selected,
      button: true,
      label: '$label theme',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _setTheme(mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? brand.bg : p.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: selected ? p.accent : p.muted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: staffBody(15, weight: FontWeight.w600, color: p.ink)),
                    const SizedBox(height: 2),
                    Text(sub, style: staffBody(12, color: p.muted)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 22,
                color: selected ? p.accent : p.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
