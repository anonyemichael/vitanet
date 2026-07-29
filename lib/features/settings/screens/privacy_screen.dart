import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        elevation: 0,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
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
            children: [
              _buildSection(
                context,
                title: 'Data Collection & Syncing',
                content: 'VitaNet securely syncs your data to our cloud servers to ensure '
                    'seamless access across your devices and to enable '
                    'health professionals to review your triage cases when necessary.\n\n'
                    'Your triage history, profile information, and preferences '
                    'are stored securely in the cloud and can be cleared from your '
                    'local device at any time from the Settings screen.',
                icon: Icons.cloud_sync_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildSection(
                context,
                title: 'Security & Protection',
                content: 'We strictly protect your medical information. All communications '
                    'between your device and our servers are heavily encrypted. Only authorized '
                    'health workers, such as registered nurses and certified doctors, can access your '
                    'triage reports if you choose to escalate a case.',
                icon: Icons.security_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildSection(
                context,
                title: 'Your Rights',
                content: 'You have the right to request the deletion of all your medical data and account '
                    'information at any time. Simply navigate to the Settings page and select '
                    '"Clear Triage History" or reach out to our support team.',
                icon: Icons.gavel_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required String content, required IconData icon, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            Expanded(
              child: Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          content,
          style: context.textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
