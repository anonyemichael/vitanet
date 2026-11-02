import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/data/services/referral_service.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Backend triage level for an app [TriageLevel].
String referralLevelFor(TriageLevel l) => switch (l) {
  TriageLevel.emergency => 'urgent',
  TriageLevel.doctor => 'doctor',
  TriageLevel.pharmacist => 'pharmacist',
  TriageLevel.selfCare => 'self_care',
};

String _levelLabel(TriageLevel l) => switch (l) {
  TriageLevel.emergency => 'Urgent — emergency department',
  TriageLevel.doctor => 'See a doctor within 24 hours',
  TriageLevel.pharmacist => 'Speak to a pharmacist',
  TriageLevel.selfCare => 'Self-care',
};

String _vitalLabel(String key) => switch (key) {
  'heart_rate' => 'Heart rate (bpm)',
  'blood_oxygen' => 'Blood oxygen (%)',
  'respiratory_rate' => 'Breathing rate (/min)',
  'body_temperature' => 'Temperature (°C)',
  'blood_pressure_systolic' => 'Blood pressure, systolic',
  'blood_pressure_diastolic' => 'Blood pressure, diastolic',
  'blood_glucose' => 'Blood glucose',
  _ => key.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
};

String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

/// Result of the send sheet.
class ReferralSheetOutcome {
  final Referral referral;

  /// True when the backend refused because a referral was already open and
  /// [referral] is that existing one.
  final bool alreadyOpen;
  const ReferralSheetOutcome(this.referral, {this.alreadyOpen = false});
}

/// Opens the "Send my summary to a hospital" sheet.
Future<ReferralSheetOutcome?> showSendReferralSheet(BuildContext context, TriageResult result) {
  return showVnSheet<ReferralSheetOutcome>(context, builder: (ctx) => SendReferralSheet(result: result));
}

/// Choose a hospital, review exactly what will be shared, consent, send.
class SendReferralSheet extends ConsumerStatefulWidget {
  final TriageResult result;
  const SendReferralSheet({super.key, required this.result});

  @override
  ConsumerState<SendReferralSheet> createState() => _SendReferralSheetState();
}

class _SendReferralSheetState extends ConsumerState<SendReferralSheet> {
  String? _selectedId;
  bool _consent = false;
  bool _allergies = true;
  bool _medications = true;
  bool _conditions = true;
  bool _vitals = true;
  bool _location = true;
  bool _sending = false;
  String? _error;

  String get _complaint {
    final r = widget.result;
    final s = r.primarySymptom.trim().isNotEmpty ? r.primarySymptom.trim() : r.summary.trim();
    // The API needs at least 2 characters; say plainly when nothing was named.
    return s.length >= 2 ? _clip(s, 300) : 'Symptom check (no main symptom recorded)';
  }

  ReferralRequest _buildRequest(
    Facility f,
    UserProfile? profile,
    Map<String, double> vitals,
    DeviceLocation? loc,
  ) {
    final r = widget.result;
    final name = profile?.name.trim() ?? '';
    final sex = profile?.sex?.trim() ?? '';
    return ReferralRequest(
      hospitalId: f.id,
      consent: _consent,
      triageLevel: referralLevelFor(r.level),
      complaint: _complaint,
      triageSummary: r.summary.trim().isEmpty ? null : _clip(r.summary.trim(), 2000),
      patientName: name.isEmpty ? null : _clip(name, 150),
      age: profile?.age,
      sex: sex.isEmpty ? null : _clip(sex, 16),
      allergies: _allergies ? (profile?.allergies ?? const []) : const [],
      medications: _medications ? (profile?.medications ?? const []) : const [],
      conditions: _conditions ? (profile?.preExistingConditions ?? const []) : const [],
      vitals: _vitals ? Map<String, dynamic>.from(vitals) : const {},
      latitude: _location ? loc?.latitude : null,
      longitude: _location ? loc?.longitude : null,
    );
  }

  Future<void> _send(
    Facility f,
    UserProfile? profile,
    Map<String, double> vitals,
    DeviceLocation? loc,
  ) async {
    if (!_consent || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final service = ref.read(referralServiceProvider);
    try {
      final referral = await service.create(_buildRequest(f, profile, vitals, loc));
      ref.read(sessionReferralIdProvider.notifier).state = referral.id;
      ref.invalidate(myReferralsProvider);
      if (mounted) Navigator.of(context).pop(ReferralSheetOutcome(referral));
    } on ReferralException catch (e) {
      if (e.isOpenReferralConflict) {
        Referral? open;
        try {
          for (final r in await service.mine()) {
            if (r.isOpen) {
              open = r;
              break;
            }
          }
        } on ReferralException {
          // fall through to the message below
        }
        ref.invalidate(myReferralsProvider);
        if (open != null) {
          ref.read(sessionReferralIdProvider.notifier).state = open.id;
          if (mounted) Navigator.of(context).pop(ReferralSheetOutcome(open, alreadyOpen: true));
          return;
        }
      }
      if (e.statusCode == 409 && !e.isOpenReferralConflict) ref.invalidate(nearbyFacilitiesProvider);
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not send your summary. Nothing was shared. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final facilities = ref.watch(nearbyFacilitiesProvider);
    final maxH = MediaQuery.of(context).size.height * 0.92;

    final List<Widget> body = facilities.when(
      loading: () => [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
        Text(
          'Finding hospitals near you…',
          textAlign: TextAlign.center,
          style: VnText.body(14, color: p.muted),
        ),
      ],
      error: (e, _) => [
        _EmergencyFallback(
          message: e is ReferralException
              ? e.message
              : 'Could not load hospitals right now. Call 112 in an emergency.',
          onRetry: () => ref.invalidate(nearbyFacilitiesProvider),
        ),
      ],
      data: (list) => list.isEmpty
          ? [
              const _EmergencyFallback(
                message: 'No hospitals near you use VitaNet yet — call 112 in an emergency',
              ),
            ]
          : _form(context, p, list),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SingleChildScrollView(
        child: VnSheet(
          gap: 14,
          children: [
            Text('Send my summary to a hospital', style: VnText.heading(20, color: p.ink)),
            Text(
              'The hospital sees your summary before you arrive and can accept or decline. '
              'This is not an ambulance — call 112 in an emergency.',
              style: VnText.body(13, color: p.muted, height: 1.45),
            ),
            ...body,
          ],
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context, VnPalette p, List<Facility> list) {
    final accepting = list.where((f) => f.acceptingReferrals).toList();
    if (_selectedId == null || !accepting.any((f) => f.id == _selectedId)) {
      _selectedId = accepting.isEmpty ? null : accepting.first.id;
    }
    final selected = accepting.where((f) => f.id == _selectedId).firstOrNull;
    final profile = ref.watch(referralProfileProvider);
    final vitals = ref.watch(referralVitalsProvider);
    final loc = ref.watch(currentLocationProvider).valueOrNull;
    final r = widget.result;

    String listOr(List<String> v, String none) => v.isEmpty ? none : v.join(', ');
    final hasProfile = profile != null && profile.name.trim().isNotEmpty;

    return [
      VnSectionLabel('1. Choose a hospital', padding: EdgeInsets.zero),
      for (final f in list)
        _FacilityTile(
          facility: f,
          selected: f.id == _selectedId,
          onTap: f.acceptingReferrals && !_sending ? () => setState(() => _selectedId = f.id) : null,
        ),
      if (accepting.isEmpty)
        const _EmergencyFallback(
          message:
              'None of these hospitals are taking VitaNet referrals right now — '
              'call 112 in an emergency',
        ),
      if (selected != null) ...[
        VnSectionLabel('2. What will be shared with ${selected.name}', padding: EdgeInsets.zero),
        if (!hasProfile)
          Text(
            'You haven\'t set up a health profile, so items marked "Not set" won\'t be shared.',
            style: VnText.body(13, color: p.muted, height: 1.4),
          ),
        VnCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              _ShareRow(label: 'Name', value: hasProfile ? profile.name.trim() : 'Not set'),
              _ShareRow(label: 'Age', value: profile?.age?.toString() ?? 'Not set'),
              _ShareRow(
                label: 'Sex',
                value: (profile?.sex?.trim().isNotEmpty ?? false) ? profile!.sex!.trim() : 'Not set',
              ),
              _ShareRow(label: 'Symptoms', value: _complaint),
              _ShareRow(
                label: 'Triage',
                value: r.summary.trim().isEmpty
                    ? _levelLabel(r.level)
                    : '${_levelLabel(r.level)}\n${r.summary.trim()}',
              ),
              _ShareRow(
                label: 'Allergies',
                note: 'Recommended — helps staff treat you safely',
                value: listOr(profile?.allergies ?? const [], 'None recorded'),
                optional: true,
                included: _allergies,
                onChanged: _sending ? null : (v) => setState(() => _allergies = v),
              ),
              _ShareRow(
                label: 'Medications',
                value: listOr(profile?.medications ?? const [], 'None recorded'),
                optional: true,
                included: _medications,
                onChanged: _sending ? null : (v) => setState(() => _medications = v),
              ),
              _ShareRow(
                label: 'Conditions',
                value: listOr(profile?.preExistingConditions ?? const [], 'None recorded'),
                optional: true,
                included: _conditions,
                onChanged: _sending ? null : (v) => setState(() => _conditions = v),
              ),
              _ShareRow(
                label: 'Latest vitals',
                value: vitals.isEmpty
                    ? 'None recorded'
                    : vitals.entries.map((e) => '${_vitalLabel(e.key)}: ${_num(e.value)}').join('\n'),
                optional: true,
                included: _vitals,
                onChanged: _sending ? null : (v) => setState(() => _vitals = v),
              ),
              if (loc != null)
                _ShareRow(
                  label: 'Location',
                  note: 'Used to estimate when you\'ll arrive',
                  value: 'Your approximate current location',
                  optional: true,
                  included: _location,
                  onChanged: _sending ? null : (v) => setState(() => _location = v),
                  last: true,
                ),
            ],
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            key: const Key('referral-consent'),
            value: _consent,
            onChanged: _sending ? null : (v) => setState(() => _consent = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: p.brand,
            title: Text(
              'I agree to share the information above with ${selected.name} for my care.',
              style: VnText.body(14, color: p.ink, height: 1.4),
            ),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: VnText.body(13, weight: FontWeight.w600, color: p.danger),
          ),
        VnButton(
          label: _sending ? 'Sending…' : 'Send to ${selected.name}',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _consent && !_sending
              ? () => _send(selected, profile, vitals, _location ? loc : null)
              : null,
        ),
        if (!_consent)
          Text(
            'Tick the box above to send.',
            textAlign: TextAlign.center,
            style: VnText.body(12, color: p.muted),
          ),
      ],
    ];
  }
}

class _FacilityTile extends StatelessWidget {
  final Facility facility;
  final bool selected;
  final VoidCallback? onTap;
  const _FacilityTile({required this.facility, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final f = facility;
    final meta = [
      if (f.distanceKm != null) '${f.distanceKm!.toStringAsFixed(1)} km',
      if (f.etaMinutes != null) '~${f.etaMinutes} min',
      if (!f.acceptingReferrals) 'Not taking referrals right now',
    ].join(' · ');
    return Semantics(
      selected: selected,
      child: VnCard(
        onTap: onTap,
        borderColor: selected ? p.brand : null,
        borderWidth: selected ? 2 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Opacity(
          opacity: f.acceptingReferrals ? 1 : 0.55,
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? p.brand : p.faint,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: VnText.body(15, weight: FontWeight.w700, color: p.ink),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta, style: VnText.body(13, color: p.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final bool included;
  final ValueChanged<bool>? onChanged;
  final bool optional;
  final bool last;

  const _ShareRow({
    required this.label,
    required this.value,
    this.note,
    this.included = true,
    this.onChanged,
    this.optional = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: VnText.body(12, weight: FontWeight.w700, color: p.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  included ? value : 'Not shared',
                  style: VnText.body(14, color: included ? p.ink : p.faint, height: 1.4),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: VnText.body(11, color: p.muted)),
                ],
              ],
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 8),
            VnSwitch(value: included, onChanged: onChanged, semanticLabel: 'Share $label'),
          ],
        ],
      ),
    );
  }
}

class _EmergencyFallback extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _EmergencyFallback({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return VnCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: VnText.body(14, weight: FontWeight.w600, color: p.ink, height: 1.45),
          ),
          const SizedBox(height: 12),
          VnButton(
            label: 'Call 112',
            icon: Icons.call_rounded,
            background: const Color(0xFFB91C1C),
            foreground: Colors.white,
            onPressed: () => LaunchHelpers.dialOrSnack(context, '112'),
          ),
          const SizedBox(height: 8),
          VnOutlineButton(
            label: 'Find nearest A&E',
            icon: Icons.map_outlined,
            onPressed: () => LaunchHelpers.openPharmacyOrSnack(context, 'emergency room near me'),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            VnOutlineButton(label: 'Try again', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}
