import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

class AdminSecuritySettingsPage extends StatefulWidget {
  const AdminSecuritySettingsPage({super.key});

  @override
  State<AdminSecuritySettingsPage> createState() => _SecurityAdminSettingsPageState();
}

class _SecurityAdminSettingsPageState extends State<AdminSecuritySettingsPage> {
  bool _biometricAuth = true;
  bool _twoFactorAuth = false;
  
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isUpdatingPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword(BuildContext context) async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isUpdatingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate user
        final cred = EmailAuthProvider.credential(
          email: user.email!, 
          password: _currentPasswordController.text
        );
        await user.reauthenticateWithCredential(cred);
        
        // Update password
        await user.updatePassword(_newPasswordController.text);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access Key updated successfully!'), backgroundColor: Colors.green),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPassword = false);
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    }
  }

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
      barrierDismissible: !_isUpdatingPassword,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Update Access Key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true, 
                  decoration: const InputDecoration(labelText: 'Current Key', prefixIcon: Icon(Icons.lock_outline))
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true, 
                  decoration: const InputDecoration(labelText: 'New Key', prefixIcon: Icon(Icons.key))
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true, 
                  decoration: const InputDecoration(labelText: 'Confirm New Key', prefixIcon: Icon(Icons.key))
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isUpdatingPassword ? null : () {
                  _currentPasswordController.clear();
                  _newPasswordController.clear();
                  _confirmPasswordController.clear();
                  Navigator.pop(context);
                }, 
                child: const Text('Cancel')
              ),
              ElevatedButton(
                onPressed: _isUpdatingPassword ? null : () async {
                  setStateDialog(() => _isUpdatingPassword = true);
                  await _updatePassword(context);
                  if (mounted) setStateDialog(() => _isUpdatingPassword = false);
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isUpdatingPassword 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Update'),
              ),
            ],
          );
        }
      ),
    );
  }
}


