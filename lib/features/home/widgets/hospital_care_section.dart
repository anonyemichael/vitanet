import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/features/portal/data/portal_models.dart' as portal;
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/home/screens/hospital_directory_screen.dart';
import 'package:vitanet/features/home/widgets/emergency_checkin_sheet.dart';
import 'package:vitanet/features/history/screens/patient_visits_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Hospital Care & Emergency Network section embedded on HomeScreen.
/// Bridges the patient app with real hospital capacity, live ER check-ins,
/// and inpatient care tracking.
class HospitalCareSection extends ConsumerWidget {
  const HospitalCareSection({super.key});

  void _openDirectory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HospitalDirectoryScreen()),
    );
  }

  void _openVisits(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatientVisitsScreen()),
    );
  }

  void _callHospital(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency contact number listed.')),
      );
      return;
    }
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $phone')),
        );
      }
    }
  }

  void _showEmergencyCheckinSheet(BuildContext context, WidgetRef ref, dynamic hospital) =>
      showEmergencyCheckin(context, hospitalId: hospital.id.toString(), hospitalName: hospital.name as String);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final facilitiesAsync = ref.watch(nearbyFacilitiesProvider);
    final patientCasesAsync = ref.watch(patientCasesProvider);

    final activeCase = patientCasesAsync.valueOrNull?.where((c) => !c.isDischarged).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VnSectionHeader(
          title: 'Hospital Care & Emergency',
          action: 'View all',
          onAction: () => _openDirectory(context),
        ),
        const SizedBox(height: 12),

        // Active Inpatient Admission Banner (if admitted)
        if (activeCase != null) ...[
          _ActiveInpatientCard(
            patientCase: activeCase,
            onTap: () => _openVisits(context),
          ),
          const SizedBox(height: 12),
        ],

        // Nearest Facility & Live ER Card
        facilitiesAsync.when(
          loading: () => Container(
            height: 130,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Icon(Icons.local_hospital_outlined, color: p.muted, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hospital directory currently syncing',
                    style: VnText.body(13, color: p.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(nearbyFacilitiesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (facilities) {
            if (facilities.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: Text(
                  'No affiliated hospitals in direct range.',
                  style: VnText.body(13, color: p.muted),
                ),
              );
            }

            final nearest = facilities.first;
            final bedsFree = nearest.bedsFree;
            final bedsTotal = nearest.bedsTotal;
            final hasBedInfo = bedsTotal > 0;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Facility Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: p.isDark ? const Color(0x262DD4BF) : const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: p.isDark ? const Color(0x402DD4BF) : const Color(0xFFCCFBF1),
                          ),
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          size: 22,
                          color: AppColors.brandDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    nearest.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: VnText.heading(16, color: p.ink),
                                  ),
                                ),
                                if (nearest.distanceKm != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: p.surfaceAlt,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${nearest.distanceKm!.toStringAsFixed(1)} km',
                                      style: VnText.body(11, weight: FontWeight.w700, color: p.muted),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nearest.address ?? 'Emergency Medical Center',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VnText.body(12, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Status Badges (ER status, beds, drive time)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (nearest.hasEmergencyRoom)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x1F10B981),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '24/7 ER Active',
                                style: VnText.body(11, weight: FontWeight.w700, color: const Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                      if (hasBedInfo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: bedsFree > 0 ? const Color(0x1F0284C7) : const Color(0x1FEF4444),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$bedsFree of $bedsTotal beds free',
                            style: VnText.body(11,
                                weight: FontWeight.w700,
                                color: bedsFree > 0 ? const Color(0xFF0369A1) : const Color(0xFFB91C1C)),
                          ),
                        ),
                      if (nearest.etaMinutes != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '~${nearest.etaMinutes} min ETA',
                            style: VnText.body(11, weight: FontWeight.w600, color: p.muted),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons: 1-Tap ER Check-In & Call
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showEmergencyCheckinSheet(context, ref, nearest),
                          icon: const Icon(Icons.emergency_rounded, size: 17, color: Colors.white),
                          label: const Text('ER Pre-Arrival Check-In'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Call Emergency Desk',
                        onPressed: () => _callHospital(context, nearest.phoneNumber),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Active Inpatient Admission Card showing bed stay & physician info.
class _ActiveInpatientCard extends StatelessWidget {
  final portal.PatientHospitalCase patientCase;
  final VoidCallback onTap;

  const _ActiveInpatientCard({
    required this.patientCase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.staffNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x332DD4BF)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x2E2DD4BF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.bed_rounded, size: 14, color: AppColors.mintLight),
                          SizedBox(width: 4),
                          Text(
                            'Active Hospital Stay',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mintLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  patientCase.hospitalName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ward: ${patientCase.ward ?? "General"} · Bed: ${patientCase.bed ?? "Triage"} · ${patientCase.attendingDoctor ?? "ER Team"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Text(
                      'View Inpatient Flow Sheet & Doctor Orders',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mintLight,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.mintLight),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
