import 'package:flutter/material.dart';
import 'profile_settings_page.dart';
import 'app_preferences_page.dart';
import 'security_settings_page.dart';

class SettingsPage extends StatelessWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;
  final VoidCallback onNavigateToNotifications;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
    required this.onNavigateToNotifications,
  });

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate Session'),
        content: const Text('Are you sure you want to securely sign out of the clinical system?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session terminated successfully.'), behavior: SnackBarBehavior.floating),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _handleSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clinical Support'),
        content: const Text('For urgent technical issues, please contact the IT department at ext. 555 or email support@hospital.sys'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
      appBar: AppBar(
        title: const Text('Clinical Configuration'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double horizontalPadding = constraints.maxWidth > 800 ? (constraints.maxWidth - 800) / 2 : 16;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: ListView(
              children: [
                const SizedBox(height: 12),
                _buildConfigCard(
                  context,
                  Icons.account_box_outlined,
                  'Clinical Identity',
                  'Manage your professional profile and bio',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileSettingsPage()),
                  ),
                ),
                _buildConfigCard(
                  context,
                  Icons.notifications_active_outlined,
                  'Alert Registry',
                  'Review and manage clinical priority alerts',
                  onTap: onNavigateToNotifications,
                ),
                _buildConfigCard(
                  context,
                  Icons.display_settings_outlined,
                  'Interface Preferences',
                  'Customize visual themes and accessibility',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppPreferencesPage(
                        onThemeChanged: onThemeChanged,
                        currentThemeMode: currentThemeMode,
                      ),
                    ),
                  ),
                ),
                _buildConfigCard(
                  context,
                  Icons.admin_panel_settings_outlined,
                  'Access & Security',
                  'Manage credentials and session privacy',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SecuritySettingsPage()),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Divider(color: Colors.black12),
                ),
                _buildConfigCard(
                  context,
                  Icons.support_agent_outlined,
                  'Technical Support',
                  'Access system documentation and FAQ',
                  onTap: () => _handleSupport(context),
                ),
                _buildConfigCard(
                  context,
                  Icons.power_settings_new_outlined,
                  'Terminate Session',
                  'Securely sign out of the clinical system',
                  isDestructive: true,
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigCard(
    BuildContext context,
    IconData icon, String title, String sub, {
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDestructive ? colorScheme.error.withAlpha(20) : colorScheme.primary.withAlpha(10),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDestructive ? colorScheme.error.withAlpha(20) : colorScheme.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: isDestructive ? colorScheme.error : colorScheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDestructive ? colorScheme.error : colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant.withAlpha(100)),
        onTap: onTap,
      ),
    );
  }
}
