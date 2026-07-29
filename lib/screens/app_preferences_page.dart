import 'package:flutter/material.dart';

class AppPreferencesPage extends StatelessWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const AppPreferencesPage({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

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
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: const Text('High Contrast Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Enhanced visibility for clinical data'),
            secondary: Icon(Icons.visibility_outlined, color: colorScheme.primary),
            value: false,
            onChanged: (val) {},
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.translate_outlined, color: colorScheme.primary),
            title: const Text('System Language', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('English (Global Clinical Standards)'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {},
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
    final isSelected = currentThemeMode == mode;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onThemeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withAlpha(15) : Colors.transparent,
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
    );
  }
}
