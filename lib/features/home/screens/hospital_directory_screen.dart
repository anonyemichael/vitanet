import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Full searchable directory of affiliated hospitals and emergency trauma centers.
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

  void _showPreArrivalModal(BuildContext context, dynamic hospital) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PreArrivalSheet(hospital: hospital),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final facilitiesAsync = ref.watch(nearbyFacilitiesProvider);

    return Scaffold(
      backgroundColor: p.page,
      appBar: AppBar(
        title: const Text('Hospitals & Medical Centers', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: p.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search hospital name, city, or district…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: p.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('24/7 ER Only'),
                        selected: _emergencyOnly,
                        onSelected: (val) => setState(() => _emergencyOnly = val),
                        backgroundColor: p.surfaceAlt,
                        selectedColor: const Color(0x2E10B981),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _emergencyOnly ? const Color(0xFF047857) : p.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Beds Available'),
                        selected: _hasBedsOnly,
                        onSelected: (val) => setState(() => _hasBedsOnly = val),
                        backgroundColor: p.surfaceAlt,
                        selectedColor: const Color(0x2E0284C7),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _hasBedsOnly ? const Color(0xFF0369A1) : p.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Ambulance Dispatch'),
                        selected: _ambulanceOnly,
                        onSelected: (val) => setState(() => _ambulanceOnly = val),
                        backgroundColor: p.surfaceAlt,
                        selectedColor: const Color(0x2EF59E0B),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ambulanceOnly ? const Color(0xFFB45309) : p.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

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
                    ElevatedButton(
                      onPressed: () => ref.invalidate(nearbyFacilitiesProvider),
                      child: const Text('Retry'),
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
                                child: ElevatedButton.icon(
                                  onPressed: () => _showPreArrivalModal(context, fac),
                                  icon: const Icon(Icons.emergency_rounded, size: 16),
                                  label: const Text('ER Pre-Arrival Check-In'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _callHospital(context, fac.phoneNumber),
                                icon: const Icon(Icons.call_rounded, size: 15),
                                label: const Text('Call'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
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
    );
  }
}

class _PreArrivalSheet extends ConsumerStatefulWidget {
  final dynamic hospital;
  const _PreArrivalSheet({required this.hospital});

  @override
  ConsumerState<_PreArrivalSheet> createState() => _PreArrivalSheetState();
}

class _PreArrivalSheetState extends ConsumerState<_PreArrivalSheet> {
  final _ctrl = TextEditingController();
  int _eta = 15;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final complaint = _ctrl.text.trim();
    if (complaint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the symptom or chief complaint.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await ref.read(hospitalApiProvider).emergencyCheckin(
        widget.hospital.id.toString(),
        complaint: complaint,
        etaMinutes: _eta,
      );
      ref.invalidate(nearbyFacilitiesProvider);
      ref.invalidate(patientCasesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            content: Text('${res.message} Case registered (#${res.caseId})'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Emergency Pre-Arrival · ${widget.hospital.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Emergency complaint (e.g. Difficulty breathing, severe trauma, acute pain)',
              filled: true,
              fillColor: p.surfaceAlt,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [10, 15, 25, 40].map((m) {
              final active = _eta == m;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text('${m}m'),
                    selected: active,
                    onSelected: (_) => setState(() => _eta = m),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Dispatch Pre-Arrival to ER Triage', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
