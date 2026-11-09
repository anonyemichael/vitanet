import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

/// Shared page frame for admin pages: back button, title, centred content.
class _AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  const _AdminScaffold({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                  child: Row(children: [
                    if (Navigator.of(context).canPop())
                      CIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop())
                    else
                      const SizedBox(width: 12),
                    Expanded(child: Text(title, style: cText(22, weight: FontWeight.w700, color: p.ink))),
                  ]),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Team & join requests ───

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  Future<void> _review(BuildContext context, WidgetRef ref, TeamMember m, String action, {StaffRole? role}) async {
    final api = ref.read(hospitalApiProvider);
    final done = switch (action) {
      'approve' => 'approved as ${(role ?? m.role).label.toLowerCase()}',
      'reject' => 'declined',
      'suspend' => 'suspended',
      'reinstate' => 'reinstated',
      _ => 'updated',
    };
    final res = await runCAction(
      context,
      () => action == 'role' ? api.changeStaffRole(m.firebaseUid, role!) : api.reviewStaff(m.firebaseUid, action, role: role),
      success: action == 'role' ? '${m.fullName} is now ${role!.label.toLowerCase()}.' : '${m.fullName} $done.',
    );
    if (res != null) {
      ref.invalidate(teamProvider);
      ref.invalidate(capacityProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  Future<void> _manage(BuildContext context, WidgetRef ref, TeamMember m) async {
    final p = ClinicalPalette.of(context);
    final choice = await showCSheet<String>(
      context,
      builder: (ctx) => CSheet(
        title: m.fullName,
        subtitle: '${m.role.label} · ${m.email ?? ''}',
        gap: 8,
        children: [
          if (m.status == StaffStatus.approved) ...[
            for (final r in StaffRole.values.where((r) => r != m.role))
              COption(
                leading: Icon(Icons.badge_outlined, color: p.ink),
                title: 'Make ${r.label.toLowerCase()}',
                selected: false,
                onTap: () => Navigator.pop(ctx, 'role:${r.api}'),
              ),
            COption(
              leading: Icon(Icons.pause_circle_outline_rounded, color: p.tone(Tone.red).fg),
              title: 'Suspend access',
              subtitle: 'They can still use their personal VitaNet',
              selected: false,
              onTap: () => Navigator.pop(ctx, 'suspend'),
            ),
          ] else
            COption(
              leading: Icon(Icons.play_circle_outline_rounded, color: p.tone(Tone.green).fg),
              title: 'Reinstate',
              selected: false,
              onTap: () => Navigator.pop(ctx, 'reinstate'),
            ),
          Text("You can't change your own account, and the hospital always keeps at least one admin.",
              style: cText(12, color: p.muted)),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice.startsWith('role:')) {
      await _review(context, ref, m, 'role', role: StaffRole.parse(choice.substring(5)));
    } else if (choice == 'suspend') {
      final ok = await confirmC(context,
          title: 'Suspend ${m.fullName}?',
          message: 'They lose access to the portal straight away. You can reinstate them later.',
          confirm: 'Suspend',
          danger: true);
      if (ok && context.mounted) await _review(context, ref, m, 'suspend');
    } else {
      await _review(context, ref, m, choice);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final me = ref.watch(staffAccessProvider).valueOrNull?.me;
    final value = ref.watch(teamProvider);
    return _AdminScaffold(
      title: 'Team',
      body: RefreshIndicator(
        color: p.primary,
        onRefresh: () => ref.refresh(teamProvider.future),
        child: value.when(
          loading: () => ListView(children: const [CLoading()]),
          error: (e, _) => ListView(children: [CError(error: e, onRetry: () => ref.invalidate(teamProvider))]),
          data: (team) {
            final pending = team.where((m) => m.status == StaffStatus.pending).toList();
            final staff = team.where((m) => m.status != StaffStatus.pending && m.status != StaffStatus.rejected).toList()
              ..sort((a, b) => a.fullName.compareTo(b.fullName));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (pending.isNotEmpty) ...[
                  CSectionLabel('Want to join · ${pending.length}'),
                  const SizedBox(height: 8),
                  for (final m in pending) ...[
                    CCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            CAvatar(m.fullName, size: 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.fullName, style: cText(15, weight: FontWeight.w600, color: p.ink)),
                                Text(m.email ?? '', style: cText(12, color: p.muted)),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(children: [
                              const TextSpan(text: 'Asked for '),
                              TextSpan(text: m.role.label, style: cText(13, weight: FontWeight.w700, color: p.ink)),
                              const TextSpan(text: '   Licence '),
                              TextSpan(
                                text: (m.licenseNumber ?? '').isEmpty ? 'not given' : m.licenseNumber,
                                style: cMono(13, color: (m.licenseNumber ?? '').isEmpty ? p.tone(Tone.orange).fg : p.ink),
                              ),
                            ]),
                            style: cText(13, color: p.muted),
                          ),
                          if ((m.department ?? '').isNotEmpty)
                            Text('Department: ${m.department}', style: cText(13, color: p.muted)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: CButton('Decline',
                                  kind: CButtonKind.secondary, height: 40, onPressed: () => _review(context, ref, m, 'reject')),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: CButton('Approve as ${m.role.label.toLowerCase()}',
                                  height: 40, onPressed: () => _review(context, ref, m, 'approve', role: m.role)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                ],
                CSectionLabel('Staff · ${staff.length}'),
                const SizedBox(height: 8),
                CCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < staff.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: p.divider),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          child: Row(children: [
                            CAvatar(staff[i].fullName, size: 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(staff[i].fullName, style: cText(15, weight: FontWeight.w600, color: p.ink)),
                                Text(
                                  [staff[i].role.label, if ((staff[i].department ?? '').isNotEmpty) staff[i].department!].join(' · '),
                                  style: cText(12, color: p.muted),
                                ),
                              ]),
                            ),
                            CChip(
                              staff[i].status == StaffStatus.suspended
                                  ? 'Suspended'
                                  : staff[i].onDuty
                                      ? 'On shift'
                                      : 'Off shift',
                              tone: staff[i].status == StaffStatus.suspended
                                  ? Tone.red
                                  : staff[i].onDuty
                                      ? Tone.green
                                      : Tone.neutral,
                            ),
                            if (staff[i].firebaseUid != me?.firebaseUid)
                              CIconButton(
                                icon: Icons.more_vert_rounded,
                                tooltip: 'Manage ${staff[i].fullName}',
                                onPressed: () => _manage(context, ref, staff[i]),
                              )
                            else
                              const SizedBox(width: 44),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Hospital profile (create & edit) ───

class FacilityFormPage extends ConsumerWidget {
  const FacilityFormPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myHospitalProvider);
    return _AdminScaffold(
      title: 'Hospital profile',
      body: value.when(
        loading: () => const CLoading(),
        error: (e, _) => CError(error: e, onRetry: () => ref.invalidate(myHospitalProvider)),
        data: (h) => FacilityForm(initial: h),
      ),
    );
  }
}

/// The hospital's public details. With no [initial] it creates the hospital
/// (an approved admin's first step).
class FacilityForm extends ConsumerStatefulWidget {
  final Facility? initial;
  const FacilityForm({super.key, this.initial});

  @override
  ConsumerState<FacilityForm> createState() => _FacilityFormState();
}

class _FacilityFormState extends ConsumerState<FacilityForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phoneNumber ?? '');
  late double? _lat = widget.initial?.latitude;
  late double? _lng = widget.initial?.longitude;
  late bool _er = widget.initial?.hasEmergencyRoom ?? true;
  late bool _ambulance = widget.initial?.hasAmbulance ?? false;
  late bool _ambulanceFree = widget.initial?.ambulanceAvailable ?? false;
  late bool _accepting = widget.initial?.acceptingReferrals ?? true;
  bool _locating = false;
  bool _saving = false;

  bool get _creating => widget.initial == null;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Turn on location services first.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission was not given.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      if (mounted) showCSnack(context, e is String ? e : "Couldn't get your location. Try again outside or near a window.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      showCSnack(context, "Add the hospital's name.");
      return;
    }
    if (_lat == null || _lng == null) {
      showCSnack(context, 'Set the map pin so patients nearby can find you.');
      return;
    }
    final input = Facility(
      name: _name.text.trim(),
      address: _address.text.trim(),
      latitude: _lat!,
      longitude: _lng!,
      phoneNumber: _phone.text.trim(),
      hasEmergencyRoom: _er,
      hasAmbulance: _ambulance,
      ambulanceAvailable: _ambulanceFree,
      acceptingReferrals: _accepting,
    );
    final api = ref.read(hospitalApiProvider);
    setState(() => _saving = true);
    final res = await runCAction(
      context,
      () => _creating ? api.createHospital(input) : api.updateHospital(input),
      success: _creating ? 'Hospital created.' : 'Saved.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res == null) return;
    ref.invalidate(myHospitalProvider);
    ref.invalidate(dashboardProvider);
    if (_creating) {
      ref.invalidate(staffAccessProvider);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _switch(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    final p = ClinicalPalette.of(context);
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: cText(15, weight: FontWeight.w600, color: p.ink)),
          Text(sub, style: cText(12, color: p.muted)),
        ]),
      ),
      CSwitch(value: value, onChanged: onChanged),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        CCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CTextField(controller: _name, label: 'Hospital name', hint: 'e.g. Ridge Regional Hospital', capitalization: TextCapitalization.words),
              const SizedBox(height: 14),
              CTextField(controller: _address, label: 'Address', hint: 'Street, town'),
              const SizedBox(height: 14),
              CTextField(controller: _phone, label: 'Emergency phone', hint: '+233 …', keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              Text('Map pin', style: cText(13, weight: FontWeight.w600, color: p.body)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Text(
                    _lat == null ? 'Not set' : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                    style: cMono(14, weight: FontWeight.w500, color: _lat == null ? p.muted : p.ink),
                  ),
                ),
                CButton(_lat == null ? 'Use my location' : 'Update',
                    kind: CButtonKind.tint, icon: Icons.my_location_rounded, expand: false, height: 40, fontSize: 13,
                    loading: _locating, onPressed: _locate),
              ]),
              const SizedBox(height: 4),
              Text('Stand at the hospital when you set this — VitaNet uses it for distance and arrival times.',
                  style: cText(12, color: p.muted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CCard(
          child: Column(
            children: [
              _switch('Emergency department', 'Shown to patients looking for an ER', _er, (v) => setState(() => _er = v)),
              const SizedBox(height: 12),
              _switch('Has ambulances', 'Patients see a call option', _ambulance, (v) => setState(() => _ambulance = v)),
              if (_ambulance) ...[
                const SizedBox(height: 12),
                _switch('Ambulance free now', 'Turn off when all are out', _ambulanceFree, (v) => setState(() => _ambulanceFree = v)),
              ],
              const SizedBox(height: 12),
              _switch('Accept VitaNet patients', 'Patients nearby can send you their summary', _accepting,
                  (v) => setState(() => _accepting = v)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CButton(_creating ? 'Create hospital' : 'Save', loading: _saving, onPressed: _save),
      ],
    );
  }
}

// ─── Activity log ───

String _actionLabel(String action) => switch (action) {
      'facility.create' => 'created the hospital',
      'facility.update' => 'edited the hospital profile',
      'facility.accepting' => 'turned on new patients',
      'facility.paused' => 'paused new patients',
      'referral.accept' => 'accepted a patient',
      'referral.decline' => 'declined a referral',
      'case.create' => 'registered a walk-in',
      'case.arrived' => 'marked a patient arrived',
      'case.update' => 'updated a record',
      'case.note' => 'added a note',
      'case.vitals' => 'recorded vitals',
      'case.prescription' => 'ordered medication',
      'case.discharge' => 'discharged a patient',
      'handover' => 'handed over patients',
      'ward.create' => 'added a ward',
      'ward.update' => 'changed a ward',
      'ward.delete' => 'removed a ward',
      'equipment.create' => 'added equipment',
      'equipment.update' => 'updated equipment',
      'equipment.delete' => 'removed equipment',
      'alert.broadcast' => 'broadcast',
      'duty.on' => 'came on shift',
      'duty.off' => 'went off shift',
      'profile.update' => 'updated their profile',
      'staff.approved' => 'approved',
      'staff.rejected' => 'declined',
      'staff.suspended' => 'suspended',
      _ => action.replaceAll('.', ' '),
    };

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final value = ref.watch(auditProvider);
    return _AdminScaffold(
      title: 'Activity log',
      body: RefreshIndicator(
        color: p.primary,
        onRefresh: () => ref.refresh(auditProvider.future),
        child: value.when(
          loading: () => ListView(children: const [CLoading()]),
          error: (e, _) => ListView(children: [CError(error: e, onRetry: () => ref.invalidate(auditProvider))]),
          data: (entries) => entries.isEmpty
              ? ListView(children: const [CEmpty(icon: Icons.history_rounded, title: 'Nothing logged yet')])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: p.divider),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final staffAction = e.action.startsWith('staff.');
                    final detail = [
                      if (staffAction && (e.target ?? '').isNotEmpty) e.target!,
                      if (e.action == 'alert.broadcast' && (e.target ?? '').isNotEmpty) '"${e.target}"',
                      if ((e.detail ?? '').isNotEmpty && !e.action.startsWith('case.vitals')) e.detail!,
                    ].join(' · ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 82, child: Text(clockTime(e.at), style: cMono(12, weight: FontWeight.w500, color: p.muted))),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: e.actor ?? 'Someone', style: cText(14, weight: FontWeight.w600, color: p.ink)),
                                TextSpan(text: ' ${_actionLabel(e.action)}'),
                                if (detail.isNotEmpty) TextSpan(text: ' · $detail', style: cText(14, color: p.muted)),
                              ]),
                              style: cText(14, color: p.body, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
