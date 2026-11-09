import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/providers/referral_providers.dart';
import 'package:vitanet/features/portal/data/hospital_api_service.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Opens the ER check-in sheet for [hospitalId].
Future<void> showEmergencyCheckin(BuildContext context, {required String hospitalId, required String hospitalName}) =>
    showVnSheet<void>(context, builder: (_) => EmergencyCheckinSheet(hospitalId: hospitalId, hospitalName: hospitalName));

/// Tells an emergency department you're on your way. Same rules as sending a
/// referral: the patient chooses what is shared, and their name never is.
class EmergencyCheckinSheet extends ConsumerStatefulWidget {
  final String hospitalId;
  final String hospitalName;
  const EmergencyCheckinSheet({super.key, required this.hospitalId, required this.hospitalName});

  @override
  ConsumerState<EmergencyCheckinSheet> createState() => _EmergencyCheckinSheetState();
}

class _EmergencyCheckinSheetState extends ConsumerState<EmergencyCheckinSheet> {
  final _complaint = TextEditingController();
  bool _shareVitals = true;
  bool _shareLocation = true;
  bool _consent = false;
  bool _sending = false;

  @override
  void dispose() {
    _complaint.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final complaint = _complaint.text.trim();
    if (complaint.length < 2) {
      _snack("Say what's wrong in a few words.");
      return;
    }
    setState(() => _sending = true);
    try {
      final loc = _shareLocation ? await ref.read(currentLocationProvider.future) : null;
      final vitals = _shareVitals ? ref.read(referralVitalsProvider) : null;
      final res = await ref.read(hospitalApiProvider).emergencyCheckin(
            widget.hospitalId,
            complaint: complaint,
            vitals: vitals,
            latitude: loc?.latitude,
            longitude: loc?.longitude,
          );
      ref.invalidate(myReferralsProvider);
      ref.invalidate(patientCasesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack(res.etaMinutes > 0
          ? '${widget.hospitalName} knows you\'re coming — about ${res.etaMinutes} min away. Follow their reply on Home.'
          : '${widget.hospitalName} knows you\'re coming. Follow their reply on Home.');
    } catch (e) {
      if (mounted) _snack(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final p = VnPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
              Text(subtitle, style: VnText.body(12, color: p.muted)),
            ],
          ),
        ),
        VnSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return VnSheet(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.dangerTint, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.emergency_rounded, color: p.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tell the ER you're coming", style: VnText.heading(18, color: p.ink)),
                  Text(widget.hospitalName, style: VnText.body(13, color: p.muted)),
                ],
              ),
            ),
          ],
        ),
        VnTextField(
          controller: _complaint,
          label: "What's wrong",
          hint: 'e.g. Chest pain spreading to my left arm',
          maxLines: 2,
        ),
        _toggle('Share my latest vitals', 'From your watch or last check', _shareVitals, (v) => setState(() => _shareVitals = v)),
        _toggle('Share my location', 'So they know when you\'ll arrive', _shareLocation, (v) => setState(() => _shareLocation = v)),
        InkWell(
          onTap: () => setState(() => _consent = !_consent),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: _consent, onChanged: (v) => setState(() => _consent = v ?? false)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'I agree to share this with ${widget.hospitalName}. My name is not shared.',
                    style: VnText.body(13, color: p.inkSoft, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ),
        VnButton(
          label: 'Send to the ER',
          background: p.danger,
          loading: _sending,
          onPressed: _consent && !_sending ? _send : null,
        ),
        Text('In a life-threatening emergency call 112 first.',
            textAlign: TextAlign.center, style: VnText.body(12, color: p.muted)),
      ],
    );
  }
}
