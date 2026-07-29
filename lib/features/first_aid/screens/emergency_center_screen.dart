import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';

class EmergencyCenterScreen extends StatelessWidget {
  const EmergencyCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Center'),
        backgroundColor: context.colorScheme.errorContainer,
        foregroundColor: context.colorScheme.onErrorContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          _buildEmergencyCallCard(context),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Critical First Aid',
            style: context.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildFirstAidCard(
            context,
            title: 'CPR (Adult)',
            icon: Icons.favorite_rounded,
            desc: 'Push hard and fast in the center of the chest.',
          ),
          _buildFirstAidCard(
            context,
            title: 'Choking',
            icon: Icons.accessibility_new_rounded,
            desc: 'Perform Heimlich maneuver (abdominal thrusts).',
          ),
          _buildFirstAidCard(
            context,
            title: 'Severe Bleeding',
            icon: Icons.water_drop_rounded,
            desc: 'Apply direct pressure and elevate if possible.',
          ),
          _buildFirstAidCard(
            context,
            title: 'Seizures',
            icon: Icons.personal_injury_rounded,
            desc: 'Clear the area, do not hold them down, time the seizure.',
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCallCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.colorScheme.error,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.error.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Is this a life-threatening emergency?',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => LaunchHelpers.dialOrSnack(context, '911'),
              icon: const Icon(Icons.phone_rounded, color: Colors.red),
              label: const Text('Call 911 Now', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAidCard(BuildContext context, {required String title, required IconData icon, required String desc}) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.colorScheme.errorContainer),
      ),
      elevation: 0,
      color: context.colorScheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.colorScheme.error),
        ),
        title: Text(title, style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(desc),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {}, // Would open detailed steps
      ),
    );
  }
}
