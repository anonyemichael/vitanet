import 'package:flutter/material.dart';
import 'admin_profile_settings_page.dart';
import 'admin_app_preferences_page.dart';
import 'admin_security_settings_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class AdminSettingsPage extends StatelessWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;
  final VoidCallback onNavigateToNotifications;

  const AdminSettingsPage({
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
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                context.go('/login');
              }
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
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Medical Service Provider';
    final email = user?.email ?? 'admin@hospital.sys';

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Settings Hub'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double horizontalPadding = constraints.maxWidth > 800 ? (constraints.maxWidth - 800) / 2 : 20;
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
            children: [
              // Premium Profile Header Card
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [colorScheme.primaryContainer.withAlpha(100), colorScheme.surfaceContainerHigh]
                      : [colorScheme.primary.withAlpha(200), colorScheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(isDark ? 0 : 50),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white.withAlpha(isDark ? 30 : 200),
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withAlpha(200),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Clinical Admin',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text('ACCOUNT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
              ),
              _buildConfigCard(
                context,
                Icons.account_circle_outlined,
                'Clinical Identity',
                'Manage your professional profile and bio',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminProfileSettingsPage())),
              ),
              _buildConfigCard(
                context,
                Icons.admin_panel_settings_outlined,
                'Access & Security',
                'Manage credentials and session privacy',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSecuritySettingsPage())),
              ),

              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text('PREFERENCES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
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
                  MaterialPageRoute(builder: (context) => AdminAppPreferencesPage(onThemeChanged: onThemeChanged, currentThemeMode: currentThemeMode)),
                ),
              ),

              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text('SYSTEM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2, color: Colors.grey)),
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
              const SizedBox(height: 40),
            ],
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
        color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(80) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: isDestructive 
            ? colorScheme.error.withAlpha(50) 
            : isDark ? colorScheme.outlineVariant : Colors.transparent,
          width: 1,
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


