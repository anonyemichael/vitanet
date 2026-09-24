import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/constants/app_strings.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedDesktopIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return _buildMobileLayout(context, ref, isDark);
          } else {
            return _buildDesktopLayout(context, ref, isDark);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _buildAppearanceSection(context, ref, isDark),
        _buildDataSection(context, ref, isDark),
        _buildSupportSection(context, ref, isDark),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar Navigation
              Container(
                width: 260,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopNavItem(0, 'Appearance', Icons.palette_rounded, isDark),
                    _buildDesktopNavItem(1, 'Data & Privacy', Icons.security_rounded, isDark),
                    _buildDesktopNavItem(2, 'Support & About', Icons.info_outline_rounded, isDark),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: SingleChildScrollView(
                    child: _buildDesktopContent(context, ref, isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem(int index, String title, IconData icon, bool isDark) {
    final isSelected = _selectedDesktopIndex == index;
    final unselectedColor = isDark ? Colors.grey.shade500 : context.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => setState(() => _selectedDesktopIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? context.colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? context.colorScheme.onPrimaryContainer : unselectedColor,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? context.colorScheme.onPrimaryContainer : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopContent(BuildContext context, WidgetRef ref, bool isDark) {
    switch (_selectedDesktopIndex) {
      case 0:
        return _buildAppearanceSection(context, ref, isDark);
      case 1:
        return _buildDataSection(context, ref, isDark);
      case 2:
        return _buildSupportSection(context, ref, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Sections ---

  Widget _buildAppearanceSection(BuildContext context, WidgetRef ref, bool isDark) {
    final currentTheme = ref.watch(themeModeProvider);
    return _buildSectionCard(
      context,
      title: 'Appearance',
      icon: Icons.palette_rounded,
      isDark: isDark,
      children: [
        _buildSettingsTile(
          context,
          icon: Icons.palette_rounded,
          title: 'Theme',
          subtitle: _themeLabel(currentTheme),
          onTap: () => _showThemePicker(context, ref, currentTheme, isDark),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context, WidgetRef ref, bool isDark) {
    return _buildSectionCard(
      context,
      title: 'Data & Privacy',
      icon: Icons.security_rounded,
      isDark: isDark,
      children: [
        _buildSettingsTile(
          context,
          icon: Icons.delete_outline_rounded,
          title: 'Clear Triage History',
          subtitle: 'Permanently delete all past sessions',
          onTap: () => _confirmClearHistory(context, ref),
          isDark: isDark,
          isDestructive: true,
          showChevron: false,
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context, WidgetRef ref, bool isDark) {
    final dividerColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);
    return _buildSectionCard(
      context,
      title: 'Support & About',
      icon: Icons.info_outline_rounded,
      isDark: isDark,
      children: [
        _buildSettingsTile(
          context,
          icon: Icons.info_outline_rounded,
          title: 'About VitaNet',
          subtitle: 'Version 1.0.0',
          onTap: () => context.push('/about'),
          isDark: isDark,
        ),
        Divider(height: 1, color: dividerColor),
        _buildSettingsTile(
          context,
          icon: Icons.gavel_rounded,
          title: 'Medical Disclaimer',
          subtitle: 'Important safety information',
          onTap: () => context.push('/disclaimer'),
          isDark: isDark,
        ),
        Divider(height: 1, color: dividerColor),
        _buildSettingsTile(
          context,
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How we handle your data',
          onTap: () => context.push('/privacy'),
          isDark: isDark,
        ),
      ],
    );
  }

  // --- Widgets ---

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required bool isDark, required List<Widget> children}) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final dividerColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: context.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
    Widget? trailing,
    bool showChevron = true,
  }) {
    final color = isDestructive ? Colors.red.shade400 : (isDark ? Colors.white : Colors.black87);
    final iconColor = isDestructive ? Colors.red.shade400 : (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700);
    final iconBgColor = isDestructive ? Colors.red.withValues(alpha: 0.1) : (isDark ? Colors.grey.shade800 : Colors.blueGrey.shade50);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null && showChevron)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  // --- Logic & Dialogs ---

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Choose Theme',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_suggest_rounded),
                ),
              ],
              selected: {current},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                ref.read(themeModeProvider.notifier).setTheme(newSelection.first);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'This will permanently delete all triage history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(triageHistoryProvider.notifier).clearAll();
              Navigator.pop(ctx);
              context.showSnack('History cleared');
            },
            child: Text(
              'Clear',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

}
