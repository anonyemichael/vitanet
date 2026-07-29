import 'package:flutter/material.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool _biometricAuth = true;
  bool _twoFactorAuth = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
      appBar: AppBar(title: const Text('Access & Security')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _buildSectionHeader(context, 'Credential Protection'),
          _buildActionTile(
            context,
            Icons.key_outlined,
            'Update Passcode',
            'Modify your secure access key',
            onTap: () => _showChangePasswordDialog(context),
          ),
          _buildSwitchTile(
            context,
            Icons.fingerprint_outlined,
            'Biometric Verification',
            'Use secure biometric data for login',
            _biometricAuth,
            (val) => setState(() => _biometricAuth = val),
          ),
          _buildSwitchTile(
            context,
            Icons.verified_outlined,
            'Multi-Factor Auth',
            'Additional layer of identity verification',
            _twoFactorAuth,
            (val) => setState(() => _twoFactorAuth = val),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Data Privacy'),
          _buildActionTile(
            context,
            Icons.history_outlined,
            'Session Registry',
            'View active sessions and login logs',
            onTap: () {},
          ),
          _buildActionTile(
            context,
            Icons.delete_outline,
            'Purge Registry Records',
            'Request deletion of clinical logs',
            onTap: () {},
            isDestructive: true,
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

  Widget _buildActionTile(
    BuildContext context,
    IconData icon,
    String title,
    String sub, {
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: isDestructive ? colorScheme.error : colorScheme.primary),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? colorScheme.error : null)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Update Access Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'Current Key')),
            SizedBox(height: 12),
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'New Key')),
            SizedBox(height: 12),
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'Confirm New Key')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Dismiss')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm Update'),
          ),
        ],
      ),
    );
  }
}
