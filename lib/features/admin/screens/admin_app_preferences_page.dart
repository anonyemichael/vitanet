import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
      appBar: AppBar(title: const Text('Interface Preferences')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _buildSectionHeader(context, 'Visual Theme'),
          const SizedBox(height: 8),
          _buildThemeOption(context, 'System Synchronized', ThemeMode.system, Icons.settings_brightness_outlined),
          _buildThemeOption(context, 'Clinical Light', ThemeMode.light, Icons.light_mode_outlined),
          _buildThemeOption(context, 'Clinical Dark', ThemeMode.dark, Icons.dark_mode_outlined),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Operational Settings'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(50) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? colorScheme.outlineVariant : Colors.transparent),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  title: const Text('High Contrast Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Enhanced visibility for clinical data'),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.visibility_outlined, color: colorScheme.primary)
                  ),
                  value: _highContrast,
                  onChanged: _setHighContrast,
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.translate_outlined, color: colorScheme.primary)
                  ),
                  title: const Text('System Language', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$_language (Global Clinical Standards)'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Language selection locked by organization.'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, ThemeMode mode, IconData icon) {
    final isSelected = widget.currentThemeMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: isSelected 
          ? colorScheme.primary.withAlpha(20) 
          : isDark ? colorScheme.surfaceContainerHighest.withAlpha(50) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onThemeChanged(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? colorScheme.primary 
                  : isDark ? colorScheme.outlineVariant : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: (isDark || isSelected) ? [] : [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 20, color: colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


