import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class QuickActionGrid extends StatelessWidget {
  final void Function(String) onAction;

  const QuickActionGrid({super.key, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Quick Actions',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionCard(
                icon: Icons.health_and_safety_rounded,
                label: 'Check Symptoms',
                color: const Color(0xFF10B981),
                onTap: () => onAction('I want to check my symptoms.'),
              ),
              _QuickActionCard(
                icon: Icons.medication_rounded,
                label: 'Medicine Reminder',
                color: const Color(0xFF3B82F6),
                onTap: () => onAction('I need to set a medicine reminder.'),
              ),
              _QuickActionCard(
                icon: Icons.local_hospital_rounded,
                label: 'Nearby Hospitals',
                color: const Color(0xFFF59E0B),
                onTap: () => onAction('Help me find a nearby hospital.'),
              ),
              _QuickActionCard(
                icon: Icons.science_rounded,
                label: 'Find Tests',
                color: const Color(0xFF8B5CF6),
                onTap: () => onAction('I want to find a medical test.'),
              ),
              _QuickActionCard(
                icon: Icons.description_rounded,
                label: 'Upload Medical Report',
                color: const Color(0xFFEF4444),
                onTap: () => onAction('I want to upload a medical report.'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: (MediaQuery.of(context).size.width - AppSpacing.md * 2 - 8) / 2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
