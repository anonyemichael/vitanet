import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final isHealthWorker =
        profile?.role == 'health_worker' || profile?.role == 'admin';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = context.theme.scaffoldBackgroundColor;
    final textColor = context.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        elevation: 0,
        backgroundColor: bgColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return _buildMobileLayout(
                context,
                ref,
                profile,
                isHealthWorker,
                isDark,
              );
            } else {
              return _buildDesktopLayout(
                context,
                ref,
                profile,
                isHealthWorker,
                isDark,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    bool isHealthWorker,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      children: [
        _buildCenteredHeader(
          context,
          ref,
          profile,
          isDark,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: AppSpacing.xxl),

        if (_needsProfileCompletion(profile)) ...[
          _buildCompletionPrompt(context, isDark),
          const SizedBox(height: AppSpacing.xl),
        ],

        if (profile != null) ...[
          _buildSectionTitle(
            context,
            'Health Overview',
            isDark,
          ).animate().fadeIn(delay: 100.ms),
          _buildHealthMetricsGrid(
            context,
            profile,
            isDark,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
          const SizedBox(height: AppSpacing.xl),
        ],

        _buildSectionTitle(
          context,
          'Account',
          isDark,
        ).animate().fadeIn(delay: 200.ms),
        _buildAccountGroup(
          context,
          isHealthWorker,
          isDark,
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
        const SizedBox(height: AppSpacing.xl),

        _buildSectionTitle(
          context,
          'Support',
          isDark,
        ).animate().fadeIn(delay: 300.ms),
        _buildSupportGroup(
          context,
          isDark,
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05),
        const SizedBox(height: AppSpacing.xxxl),

        _buildLogoutButton(context, ref, isDark).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: 120),
      ],
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  bool _needsProfileCompletion(UserProfile? profile) {
    if (profile == null) return true;
    return profile.phone == null ||
        profile.phone!.trim().isEmpty ||
        profile.dob == null ||
        profile.dob!.trim().isEmpty ||
        profile.sex == null ||
        profile.sex!.trim().isEmpty;
  }

  Widget _buildCompletionPrompt(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Complete your profile so VitaNet can personalize your health guidance.',
              style: context.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => context.push('/edit-profile'),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    bool isHealthWorker,
    bool isDark,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: _buildMobileLayout(
          context,
          ref,
          profile,
          isHealthWorker,
          isDark,
        ),
      ),
    );
  }

  Widget _buildCenteredHeader(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    bool isDark,
  ) {
    final textColor = context.colorScheme.onSurface;

    return Column(
      children: [
        _buildAvatarPicker(context, ref, profile, isDark),
        const SizedBox(height: AppSpacing.lg),
        Text(
          profile?.name ?? 'User Name',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        if (profile?.role != null) ...[
          const SizedBox(height: 4),
          Text(
            (profile!.role!).toUpperCase(),
            style: context.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarPicker(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    bool isDark,
  ) {
    final hasImage =
        profile?.profileImagePath != null &&
        profile!.profileImagePath!.isNotEmpty;
    final cardColor = context.colorScheme.surface;
    final avatarBgColor = context.colorScheme.surfaceContainerHighest;

    return GestureDetector(
      onTap: () async {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
        );

        if (image != null && profile != null) {
          final updatedProfile = profile.copyWith(profileImagePath: image.path);
          await ref
              .read(userProfileProvider.notifier)
              .updateProfile(updatedProfile);
        }
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cardColor, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 54,
              backgroundColor: avatarBgColor,
              backgroundImage: hasImage
                  ? FileImage(File(profile!.profileImagePath!))
                  : null,
              child: !hasImage
                  ? Text(
                      _getInitials(profile?.name),
                      style: context.textTheme.headlineMedium?.copyWith(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: cardColor, width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHealthMetricsGrid(
    BuildContext context,
    UserProfile profile,
    bool isDark,
  ) {
    final cardColor = context.colorScheme.surface;
    final dividerColor = context.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    context,
                    Icons.water_drop_rounded,
                    'Blood',
                    profile.bloodType ?? '--',
                    isDark,
                  ),
                ),
                VerticalDivider(width: 1, color: dividerColor),
                Expanded(
                  child: _buildMetricItem(
                    context,
                    Icons.cake_rounded,
                    'Age',
                    profile.age?.toString() ?? '--',
                    isDark,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    context,
                    Icons.monitor_weight_rounded,
                    'Weight',
                    profile.weight != null ? '${profile.weight}kg' : '--',
                    isDark,
                  ),
                ),
                VerticalDivider(width: 1, color: dividerColor),
                Expanded(
                  child: _buildMetricItem(
                    context,
                    Icons.height_rounded,
                    'Height',
                    profile.height != null ? '${profile.height}cm' : '--',
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade400,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountGroup(
    BuildContext context,
    bool isHealthWorker,
    bool isDark,
  ) {
    final cardColor = context.colorScheme.surface;
    final dividerColor = context.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildGroupedTile(
            context,
            icon: Icons.edit_document,
            title: 'Update Medical Info',
            isDark: isDark,
            onTap: () => context.push('/edit-profile'),
          ),
          if (isHealthWorker) ...[
            Divider(height: 1, indent: 56, color: dividerColor),
            _buildGroupedTile(
              context,
              icon: Icons.badge_rounded,
              title: 'Staff Credentials',
              isDark: isDark,
              onTap: () => context.showSnack('Coming soon'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportGroup(BuildContext context, bool isDark) {
    final cardColor = context.colorScheme.surface;
    final dividerColor = context.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildGroupedTile(
            context,
            icon: Icons.settings_rounded,
            title: 'App Settings',
            isDark: isDark,
            onTap: () => context.push('/settings'),
          ),
          Divider(height: 1, indent: 56, color: dividerColor),
          _buildGroupedTile(
            context,
            icon: Icons.support_agent_rounded,
            title: 'Help Center',
            isDark: isDark,
            onTap: () => context.push('/help-center'),
          ),
          Divider(height: 1, indent: 56, color: dividerColor),
          _buildGroupedTile(
            context,
            icon: Icons.info_rounded,
            title: 'About Vitanet',
            isDark: isDark,
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final iconBgColor = context.colorScheme.surfaceContainerHighest;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref, bool isDark) {
    final cardColor = context.colorScheme.surface;
    final borderColor = isDark ? Colors.red.shade900 : Colors.red.shade100;
    final textColor = isDark ? Colors.red.shade300 : Colors.red.shade600;

    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () async {
          await ref.read(userProfileProvider.notifier).clearProfile();
          await ref.read(authProvider.notifier).signOut();
          if (context.mounted) {
            context.go('/login');
          }
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1),
          ),
        ),
        icon: Icon(
          Icons.power_settings_new_rounded,
          color: textColor,
          size: 20,
        ),
        label: Text(
          'Sign Out',
          style: context.textTheme.titleSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
