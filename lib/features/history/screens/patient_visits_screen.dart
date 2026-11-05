import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/features/admin/models/portal_models.dart' as portal;
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Patient view for active hospital admissions, past inpatient visits,
/// bed stays, and official discharge summaries from hospital doctors.
class PatientVisitsScreen extends ConsumerWidget {
  const PatientVisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final casesAsync = ref.watch(patientCasesProvider);

    return Scaffold(
      backgroundColor: p.page,
      appBar: AppBar(
        title: const Text('Hospital Admissions & Care', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(patientCasesProvider.future),
        child: casesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Could not load hospital care history', style: VnText.heading(16, color: p.ink)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(patientCasesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (cases) {
            if (cases.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: p.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.local_hospital_outlined, size: 30, color: p.muted),
                      ),
                      const SizedBox(height: 16),
                      Text('No hospital admissions recorded', style: VnText.heading(17, color: p.ink)),
                      const SizedBox(height: 8),
                      Text(
                        'When you check into a hospital ER or are admitted to a ward, your clinical updates, inpatient vitals, and discharge summaries will be securely displayed here.',
                        textAlign: TextAlign.center,
                        style: VnText.body(13, color: p.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              );
            }

            final active = cases.where((c) => !c.isDischarged).toList();
            final discharged = cases.where((c) => c.isDischarged).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  VnSectionHeader(title: 'Active Inpatient Stays (${active.length})'),
                  const SizedBox(height: 10),
                  for (final c in active) ...[
                    _HospitalCaseCard(hospitalCase: c, isActive: true),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                ],
                if (discharged.isNotEmpty) ...[
                  VnSectionHeader(title: 'Past Admissions & Discharges (${discharged.length})'),
                  const SizedBox(height: 10),
                  for (final c in discharged) ...[
                    _HospitalCaseCard(hospitalCase: c, isActive: false),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HospitalCaseCard extends StatelessWidget {
  final portal.PatientHospitalCase hospitalCase;
  final bool isActive;

  const _HospitalCaseCard({
    required this.hospitalCase,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.brandDark : p.line,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0x1F2DD4BF) : p.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive ? 'Active Care Stay' : 'Discharged',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.brandDark : p.muted,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                relativeTime(hospitalCase.createdAt),
                style: VnText.body(12, color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hospitalCase.hospitalName,
            style: VnText.heading(16, color: p.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Chief Complaint: ${hospitalCase.complaint}',
            style: VnText.body(13, weight: FontWeight.w600, color: p.inkSoft),
          ),
          const SizedBox(height: 10),

          // Ward, bed, attending physician
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ward / Location', style: VnText.body(11, color: p.muted)),
                      const SizedBox(height: 2),
                      Text(
                        hospitalCase.ward ?? 'General Intake',
                        style: VnText.body(13, weight: FontWeight.w700, color: p.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bed', style: VnText.body(11, color: p.muted)),
                      const SizedBox(height: 2),
                      Text(
                        hospitalCase.bed ?? 'Triage',
                        style: VnText.body(13, weight: FontWeight.w700, color: p.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attending', style: VnText.body(11, color: p.muted)),
                      const SizedBox(height: 2),
                      Text(
                        hospitalCase.attendingDoctor ?? 'ER Team',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VnText.body(13, weight: FontWeight.w700, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Discharge summary (if discharged)
          if ((hospitalCase.dischargeSummary ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1F10B981),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x4010B981)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.assignment_turned_in_rounded, size: 16, color: Color(0xFF047857)),
                      SizedBox(width: 6),
                      Text(
                        'Doctor Discharge Summary & Instructions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hospitalCase.dischargeSummary!,
                    style: VnText.body(13, color: const Color(0xFF065F46), height: 1.45),
                  ),
                ],
              ),
            ),
          ],

          // Timeline observations
          if (hospitalCase.timeline.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Clinical Timeline & Orders (${hospitalCase.timeline.length})',
                style: VnText.body(13, weight: FontWeight.w700, color: p.ink),
              ),
              children: hospitalCase.timeline.reversed.map((event) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.brandDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.text, style: VnText.body(12, color: p.ink)),
                            Text(
                              '${event.by} · ${relativeTime(event.at)}',
                              style: VnText.body(11, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
