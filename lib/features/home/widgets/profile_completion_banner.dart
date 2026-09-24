import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class ProfileCompletionBanner extends StatelessWidget {
  const ProfileCompletionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add your age, gender, and phone number so the AI can provide better health insights.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.orange.shade100 : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            onPressed: () => context.push('/edit-profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.orange.shade300 : Colors.orange.shade600,
              foregroundColor: isDark ? Colors.black87 : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Complete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
