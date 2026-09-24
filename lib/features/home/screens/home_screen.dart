import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/premium_background.dart';
import 'package:vitanet/data/models/user_profile.dart';

// New widget imports
import 'package:vitanet/features/home/widgets/header_section.dart';
import 'package:vitanet/features/home/widgets/profile_completion_banner.dart';
import 'package:vitanet/features/home/widgets/health_overview_section.dart';
import 'package:vitanet/features/home/widgets/ai_health_alerts_section.dart';
import 'package:vitanet/features/home/widgets/care_circle_section.dart';
import 'package:vitanet/features/home/widgets/urgent_care_alert_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Defer location work so the home screen paints immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndSaveLocation();
    });
  }

  Future<void> _fetchAndSaveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Use medium accuracy — much faster than high (avoids GPS satellite lock)
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        if (!mounted) return;
        final profile = ref.read(userProfileProvider);
        if (profile != null) {
          final updatedProfile = profile.copyWith(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          ref.read(userProfileProvider.notifier).updateProfile(updatedProfile);
        }
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
    }
  }

  bool _needsProfileCompletion(UserProfile? profile) {
    if (profile == null) return true;
    return profile.phone == null ||
        profile.phone!.trim().isEmpty ||
        profile.dob == null ||
        profile.dob!.trim().isEmpty ||
        profile.sex == null ||
        profile.sex!.trim().isEmpty ||
        profile.bloodType == null ||
        profile.bloodType!.trim().isEmpty ||
        profile.height == null ||
        profile.weight == null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final needsCompletion = _needsProfileCompletion(profile);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg), // Only bottom padding
                child: Center(
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: const HeaderSection(),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 1400 : 800),
                        child: isDesktop 
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left Column
                                      Expanded(
                                        flex: 7,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: AppSpacing.sm),
                                            if (needsCompletion) const ProfileCompletionBanner(),
                                            if (needsCompletion) const SizedBox(height: AppSpacing.lg),
                                            const UrgentCareAlertBanner(),
                                            const HealthOverviewSection(),
                                            const SizedBox(height: 120),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xxxl),
                                      // Right Column
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            SizedBox(height: AppSpacing.sm),
                                            AiHealthAlertsSection(),
                                            SizedBox(height: AppSpacing.xxl),
                                            CareCircleSection(),
                                            SizedBox(height: 120),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: AppSpacing.sm),
                                    if (needsCompletion) const ProfileCompletionBanner(),
                                    if (needsCompletion) const SizedBox(height: AppSpacing.lg),
                                    const UrgentCareAlertBanner(),
                                    const HealthOverviewSection(),
                                    const SizedBox(height: AppSpacing.xxl),
                                    const AiHealthAlertsSection(),
                                    const SizedBox(height: AppSpacing.xxl),
                                    const CareCircleSection(),
                                    const SizedBox(height: 120),
                                  ],
                                ),
                        ),
                    ],
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}
