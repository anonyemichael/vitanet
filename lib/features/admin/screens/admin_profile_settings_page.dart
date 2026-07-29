import 'package:flutter/material.dart';

class AdminProfileSettingsPage extends StatefulWidget {
  const AdminProfileSettingsPage({super.key});

  @override
  State<AdminProfileSettingsPage> createState() => _ProfileAdminSettingsPageState();
}

class _ProfileAdminSettingsPageState extends State<AdminProfileSettingsPage> {
  final _nameController = TextEditingController(text: 'Medical Service Provider');
  final _bioController = TextEditingController(
      text: 'Dedicated to providing high-quality clinical care and operational excellence.');

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
      appBar: AppBar(
        title: const Text('Clinical Identity'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Identity records updated'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: colorScheme.primaryContainer.withAlpha(50),
                        child: Icon(Icons.person_outline, size: 70, color: colorScheme.primary),
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.white),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                _buildFieldLabel(context, 'Provider Designation'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.primary.withAlpha(20)),
                    ),
                    prefixIcon: Icon(Icons.badge_outlined, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                _buildFieldLabel(context, 'Professional Profile'),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.primary.withAlpha(20)),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),
                _buildInfoTile(context, 'Clinical Department', 'General Administration', Icons.business_outlined),
                _buildInfoTile(context, 'Credential ID', 'MSC-2024-001', Icons.verified_user_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(BuildContext context, String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String title, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withAlpha(10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary.withAlpha(150)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}


