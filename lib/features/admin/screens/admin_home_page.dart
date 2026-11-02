import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import '../models/alert.dart';
import '../models/hospital_data.dart';
import '../services/hospital_api_service.dart';
import '../widgets/patient_sheets.dart';
import '../widgets/staff_demo_data.dart';
import '../widgets/staff_ui.dart';
import 'admin_profile_settings_page.dart';
import 'case_management_screen.dart';

/// Staff dashboard (AdminHome.dc.html).
class AdminHomePage extends StatefulWidget {
  final VoidCallback? onOpenAlerts;
  final VoidCallback? onOpenHospital;

  const AdminHomePage({super.key, this.onOpenAlerts, this.onOpenHospital});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final ApiService _apiService = ApiService();
  HospitalStats? _stats;
  List<ClinicalAlert> _alerts = const [];
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final results = await Future.wait([
      _apiService.getDashboardStats(),
      _apiService.getAlerts(),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as HospitalStats;
      _alerts = results[1] as List<ClinicalAlert>;
      _now = DateTime.now();
    });
  }

  void _openCases() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaseManagementScreen()));
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminProfileSettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final user = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
    final name = (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName!.trim() : kDemoStaffName;

    final activeCases = (_stats?.activePatients ?? 0) > 0 ? _stats!.activePatients : 24;
    final apiCritical = _alerts.where((a) => a.isCritical).length;
    final critical = _alerts.isNotEmpty ? apiCritical : 3;
    final topPad = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: p.bg,
        body: RefreshIndicator(
          onRefresh: _loadStats,
          color: AppColors.brand,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // ── Navy header ──
              Container(
                color: AppColors.staffNavy,
                padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 16),
                child: StaffContent(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Open profile',
                              child: GestureDetector(
                                onTap: _openProfile,
                                child: const StaffPhoto(kStaffPhoto, size: 46, radius: 14, alignment: Alignment(0, -0.7)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: staffHeading(17, color: const Color(0xFFF1F5F9)),
                                  ),
                                  Text(
                                    'Emergency · $kDemoFacility',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: staffBody(12, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            StaffIconButton(
                              icon: Icons.notifications_none_rounded,
                              tooltip: 'Alerts, $critical critical',
                              background: const Color(0x14FFFFFF),
                              foreground: const Color(0xFFF1F5F9),
                              badge: critical > 0 ? '$critical' : null,
                              onPressed: widget.onOpenAlerts,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0x1A2DD4BF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x402DD4BF)),
                        ),
                        child: Row(
                          children: [
                            const StaffDot(AppColors.mint),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'On shift · 07:00–19:00',
                                style: staffBody(13, weight: FontWeight.w600, color: AppColors.mintLight),
                              ),
                            ),
                            Text(
                              DateFormat('EEE d MMM · HH:mm').format(_now),
                              style: staffBody(13, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── KPI cards overlapping the header ──
              Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 48,
                    child: Container(color: AppColors.staffNavy),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StaffContent(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth > 600 ? 4 : 2;
                          final w = (c.maxWidth - 10 * (cols - 1)) / cols;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                width: w,
                                child: _KpiCard(
                                  label: 'Active cases',
                                  value: '$activeCases',
                                  footer: _KpiFooterText('+5 since 07:00', kStaffGreen),
                                  onTap: _openCases,
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: _KpiCard(
                                  label: 'Critical now',
                                  value: '$critical',
                                  critical: true,
                                  footer: _KpiFooterText(
                                    critical == 0 ? 'All attended' : '2 unassigned',
                                    p.dark ? const Color(0xFFFCA5A5) : kStaffDanger,
                                  ),
                                  onTap: widget.onOpenAlerts,
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: _KpiCard(
                                  label: 'Beds free',
                                  value: '12',
                                  suffix: ' / 80',
                                  footer: const _KpiBar(0.85),
                                  onTap: widget.onOpenHospital,
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: _KpiCard(
                                  label: 'Avg. wait',
                                  value: '18',
                                  suffix: ' min',
                                  footer: _KpiFooterText('−6 vs yesterday', kStaffGreen),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              // ── Incoming referrals ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: StaffContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                'Incoming from VitaNet',
                                style: staffHeading(18, weight: FontWeight.w700, color: p.ink),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _openCases,
                            style: TextButton.styleFrom(
                              foregroundColor: p.accent,
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            child: Text('View all', style: staffBody(14, weight: FontWeight.w600, color: p.accent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final r in demoReferrals) ...[
                        _ReferralCard(
                          referral: r,
                          onTap: () {
                            final rec = demoRecords[r.recordId];
                            if (rec != null) {
                              showPatientRecordSheet(context, rec, onUpdated: (u) => demoRecords[u.id] = u);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Widget footer;
  final bool critical;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    this.suffix,
    required this.footer,
    this.critical = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final danger = p.tone(StaffTone.danger);
    final valueColor = critical ? (p.dark ? danger.fg : kStaffDanger) : p.ink;
    return Semantics(
      button: onTap != null,
      label: '$label: $value${suffix ?? ''}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: p.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Material(
        color: p.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: critical
              ? BorderSide(color: p.dark ? const Color(0x66DC2626) : const Color(0xFFFECACA))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: staffBody(12,
                      weight: FontWeight.w600,
                      color: critical ? (p.dark ? danger.fg : const Color(0xFF991B1B)) : p.muted),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: value,
                    children: [
                      if (suffix != null)
                        TextSpan(
                          text: suffix,
                          style: staffHeading(15, weight: FontWeight.w600, color: p.muted),
                        ),
                    ],
                  ),
                  style: staffHeading(28, color: valueColor, height: 1.1),
                ),
                const SizedBox(height: 6),
                footer,
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _KpiFooterText extends StatelessWidget {
  final String text;
  final Color color;
  const _KpiFooterText(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final c = p.dark && color == kStaffGreen ? const Color(0xFF6EE7B7) : color;
    return Text(text, style: staffBody(12, weight: FontWeight.w600, color: c));
  }
}

class _KpiBar extends StatelessWidget {
  final double value;
  const _KpiBar(this.value);

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 6,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: p.track,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  final StaffReferral referral;
  final VoidCallback onTap;
  const _ReferralCard({required this.referral, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final tone = p.tone(referral.tone);
    final r = referral;
    return Semantics(
      button: true,
      label: '${r.level} referral, ${r.nameAge}, ETA ${r.eta}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: p.card,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: tone.strong, width: 4)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.nameAge, style: staffBody(15, weight: FontWeight.w700, color: p.ink)),
                            const SizedBox(height: 2),
                            Text(r.meta, style: staffBody(12, color: p.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      StaffTag(r.level, tone: r.tone, weight: FontWeight.w800),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(r.summary, style: staffBody(13, color: p.body, height: 1.45)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            for (final v in r.vitals)
                              Text(v, style: staffBody(12, weight: FontWeight.w600, color: p.inkSoft)),
                          ],
                        ),
                      ),
                      Text('ETA ${r.eta}', style: staffBody(12, weight: FontWeight.w600, color: p.accent)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
