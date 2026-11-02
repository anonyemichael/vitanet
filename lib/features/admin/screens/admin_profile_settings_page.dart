import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import '../widgets/staff_demo_data.dart';
import '../widgets/staff_ui.dart';

/// Profile & credentials, in the staff portal visual language.
class AdminProfileSettingsPage extends StatefulWidget {
  const AdminProfileSettingsPage({super.key});

  @override
  State<AdminProfileSettingsPage> createState() => _ProfileAdminSettingsPageState();
}

class _ProfileAdminSettingsPageState extends State<AdminProfileSettingsPage> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController(
      text: 'Emergency physician focused on rapid triage, acute cardiac care and smooth handovers from VitaNet referrals.');
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final user = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    } else {
      _nameController.text = kDemoStaffName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      showStaffSnack(context, 'Enter your name as it appears on your license.');
      return;
    }
    setState(() => _isUpdating = true);
    try {
      final user = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
      if (user != null) {
        try {
          await user.updateDisplayName(_nameController.text.trim());
        } catch (_) {}
      }
      if (mounted) {
        showStaffSnack(context, 'Identity records updated successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showStaffSnack(context, 'Failed to update: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final user = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
    final credential = user != null && user.uid.length >= 8 ? user.uid.substring(0, 8).toUpperCase() : 'MDC/RN/04712';

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            StaffContent(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaffPageHeader(
                    title: 'Profile & credentials',
                    fontSize: 21,
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.staffNavy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const StaffPhoto(kStaffPhoto, size: 88, radius: 24),
                        const SizedBox(height: 12),
                        ListenableBuilder(
                          listenable: _nameController,
                          builder: (context, _) => Text(
                            _nameController.text.isEmpty ? kDemoStaffName : _nameController.text,
                            textAlign: TextAlign.center,
                            style: staffHeading(19, color: const Color(0xFFF1F5F9)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Emergency physician · $kDemoFacility',
                          textAlign: TextAlign.center,
                          style: staffBody(12, color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x1F2DD4BF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.mintLight),
                              const SizedBox(width: 6),
                              Text('Verified access',
                                  style: staffBody(12, weight: FontWeight.w600, color: AppColors.mintLight)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Identity'),
                  const SizedBox(height: 8),
                  StaffCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StaffField(
                          label: 'Full name',
                          child: TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: staffBody(15, color: p.ink),
                            decoration: staffInputDecoration(
                              context,
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        StaffField(
                          label: 'Professional profile',
                          child: TextField(
                            controller: _bioController,
                            minLines: 3,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            style: staffBody(14, color: p.ink, height: 1.5),
                            decoration: staffInputDecoration(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const StaffSectionLabel('Credentials'),
                  const SizedBox(height: 8),
                  StaffGroup(
                    children: [
                      _InfoRow(Icons.mail_outline_rounded, 'Work email', user?.email ?? 'k.mensah@korlebu.gov.gh'),
                      const _InfoRow(Icons.local_hospital_outlined, 'Department', 'Emergency'),
                      const _InfoRow(Icons.apartment_rounded, 'Facility', kDemoFacility),
                      _InfoRow(Icons.verified_user_outlined, 'Credential ID', credential),
                    ],
                  ),
                  const SizedBox(height: 20),
                  StaffButton(
                    'Save changes',
                    height: 52,
                    radius: 16,
                    loading: _isUpdating,
                    onPressed: _updateProfile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: staffBody(12, color: p.muted)),
                const SizedBox(height: 2),
                Text(value, style: staffBody(14, weight: FontWeight.w600, color: p.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
