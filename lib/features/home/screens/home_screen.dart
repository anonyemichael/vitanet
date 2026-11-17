import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

import 'package:vitanet/features/home/widgets/active_referral_section.dart';
import 'package:vitanet/features/home/widgets/header_section.dart';
import 'package:vitanet/features/home/widgets/hospital_care_section.dart';
import 'package:vitanet/features/home/widgets/profile_completion_banner.dart';
import 'package:vitanet/features/home/widgets/urgent_care_alert_banner.dart';
import 'package:vitanet/features/home/widgets/health_overview_section.dart';
import 'package:vitanet/features/home/widgets/ai_health_alerts_section.dart';
import 'package:vitanet/features/home/widgets/care_circle_section.dart';
import 'package:vitanet/features/home/widgets/wellness_insight_card.dart';

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
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        if (!mounted) return;
        final profile = ref.read(userProfileProvider);
        final me = ref.read(authProvider).user;
        if (profile == null && me != null) {
          // no profile yet (e.g. a guest): still give the assistant the location for nearby hospitals
          ref.read(apiServiceProvider).putLocation(me.uid, position.latitude, position.longitude);
        }
        if (profile != null) {   // saving the profile also sends the location to the backend
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

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final profile = ref.watch(userProfileProvider);
    final completion = ProfileCompletionBanner.completion(profile);
    const gap = SizedBox(height: 22);

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              physics: const VnAlwaysScrollablePhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              children: [
                // Order by what a person needs first (UI/UX audit UX-02): 1 urgent care, 2 symptom check,
                // 3 today's readings and alerts, 4 finding care, 5 setup and shortcuts, 6 reading.
                const HeaderSection(),
                gap,
                const ActiveReferralSection(),
                const UrgentCareAlertBanner(),
                const SymptomCheckHero(),
                gap,
                const HealthOverviewSection(),
                gap,
                const AiHealthAlertsSection(),
                gap,
                const HospitalCareSection(),
                if (completion < 1) ...[
                  gap,
                  ProfileCompletionBanner(profile: profile),
                ],
                gap,
                const CareCircleSection(),
                gap,
                const HomeQuickLinks(),
                gap,
                const WellnessInsightCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
