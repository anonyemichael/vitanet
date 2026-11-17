import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/features/portal/data/hospital_api_service.dart';
import 'package:vitanet/features/home/widgets/emergency_checkin_sheet.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Searchable list of every hospital on VitaNet, with filters for ER, beds and ambulance.
class HospitalDirectoryScreen extends ConsumerStatefulWidget {
  const HospitalDirectoryScreen({super.key});

  @override
  ConsumerState<HospitalDirectoryScreen> createState() => _HospitalDirectoryScreenState();
}

class _HospitalDirectoryScreenState extends ConsumerState<HospitalDirectoryScreen> {
  final _searchCtrl = TextEditingController();
  bool _emergencyOnly = false;
  bool _hasBedsOnly = false;
  bool _ambulanceOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _callHospital(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact number listed for this facility.')),
      );
      return;
    }
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showPreArrivalModal(BuildContext context, dynamic hospital) =>
      showEmergencyCheckin(context, hospitalId: hospital.id.toString(), hospitalName: hospital.name as String);

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final facilitiesAsync = ref.watch(nearbyFacilitiesProvider);

    // shared VitaNet components (UI/UX audit UX-13): VnTopBar, VnTextField, VnChip, VnButton
    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        bottom: false,
        child: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: p.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VnTopBar(title: 'Hospitals & clinics'),
                const SizedBox(height: 8),
                VnTextField(
                  controller: _searchCtrl,
                  hint: 'Search hospital name, city, or district…',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (_) => setState(() {}),
                  suffix: _searchCtrl.text.isEmpty
                      ? null
                      : VnIconButton(
                          icon: Icons.clear_rounded,
                          tooltip: 'Clear search',
                          iconSize: 18,
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      VnChip(
                        label: '24/7 emergency',
                        icon: Icons.emergency_outlined,
                        selected: _emergencyOnly,
                        onTap: () => setState(() => _emergencyOnly = !_emergencyOnly),
                      ),
                      const SizedBox(width: 8),
                      VnChip(
                        label: 'Beds available',
                        icon: Icons.bed_outlined,
                        selected: _hasBedsOnly,
                        onTap: () => setState(() => _hasBedsOnly = !_hasBedsOnly),
                      ),
                      const SizedBox(width: 8),
                      VnChip(
                        label: 'Has ambulance',
                        icon: Icons.airport_shuttle_outlined,
                        selected: _ambulanceOnly,
                        onTap: () => setState(() => _ambulanceOnly = !_ambulanceOnly),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: p.line),

          // Facilities List
          Expanded(
            child: facilitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Failed to load facilities: ${apiErrorMessage(e)}'),
                    const SizedBox(height: 12),
                    VnButton(
                      label: 'Try again',
                      icon: Icons.refresh_rounded,
                      expand: false,
                      onPressed: () => ref.invalidate(nearbyFacilitiesProvider),
                    ),
                  ],
                ),
              ),
              data: (facilities) {
                final query = _searchCtrl.text.trim().toLowerCase();
                final filtered = facilities.where((f) {
                  if (query.isNotEmpty) {
                    final nameMatch = f.name.toLowerCase().contains(query);
                    final addrMatch = (f.address ?? '').toLowerCase().contains(query);
                    if (!nameMatch && !addrMatch) return false;
                  }
                  if (_emergencyOnly && !f.hasEmergencyRoom) return false;
                  if (_hasBedsOnly && f.bedsFree <= 0) return false;
                  if (_ambulanceOnly && !(f.phoneNumber?.isNotEmpty ?? false)) return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: p.muted),
                          const SizedBox(height: 14),
                          Text(
                            'No facilities match your filters',
                            style: VnText.heading(16, color: p.ink),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try clearing your search query or loosening filter criteria.',
                            textAlign: TextAlign.center,
                            style: VnText.body(13, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final fac = filtered[index];
                    final bedsFree = fac.bedsFree;
                    final bedsTotal = fac.bedsTotal;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0x1F2DD4BF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.local_hospital_rounded,
                                  size: 20,
                                  color: AppColors.brandDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fac.name,
                                      style: VnText.heading(15, color: p.ink),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      fac.address ?? 'General Hospital',
                                      style: VnText.body(12, color: p.muted),
                                    ),
                                  ],
                                ),
                              ),
                              if (fac.distanceKm != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p.surfaceAlt,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${fac.distanceKm!.toStringAsFixed(1)} km',
                                    style: VnText.body(11, weight: FontWeight.w700, color: p.muted),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Badges
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (fac.hasEmergencyRoom)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1F10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '● 24/7 Emergency',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              if (bedsTotal > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: bedsFree > 0 ? const Color(0x1F0284C7) : const Color(0x1FEF4444),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$bedsFree / $bedsTotal beds free',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: bedsFree > 0 ? const Color(0xFF0369A1) : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              if (fac.etaMinutes != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: p.surfaceAlt,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '~${fac.etaMinutes}m ETA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: p.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: VnButton(
                                  label: 'Emergency check-in',
                                  icon: Icons.emergency_rounded,
                                  height: 44,
                                  fontSize: 13,
                                  background: const Color(0xFFDC2626),
                                  foreground: Colors.white,
                                  onPressed: () => _showPreArrivalModal(context, fac),
                                ),
                              ),
                              const SizedBox(width: 8),
                              VnOutlineButton(
                                label: 'Call',
                                icon: Icons.call_rounded,
                                height: 44,
                                fontSize: 13,
                                expand: false,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                onPressed: () => _callHospital(context, fac.phoneNumber),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
