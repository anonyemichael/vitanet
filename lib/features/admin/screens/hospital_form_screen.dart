import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/portal_gate_screen.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Create your hospital (POST /portal/hospitals) when [initial] is null,
/// otherwise edit the facility profile (PUT /portal/hospital).
class HospitalFormScreen extends ConsumerStatefulWidget {
  final Facility? initial;
  const HospitalFormScreen({super.key, this.initial});

  @override
  ConsumerState<HospitalFormScreen> createState() => _HospitalFormScreenState();
}

class _HospitalFormScreenState extends ConsumerState<HospitalFormScreen> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _phone = TextEditingController(text: widget.initial?.phoneNumber);
  late final _lat = TextEditingController(text: widget.initial?.latitude.toStringAsFixed(6));
  late final _lng = TextEditingController(text: widget.initial?.longitude.toStringAsFixed(6));
  late bool _er = widget.initial?.hasEmergencyRoom ?? true;
  late bool _ambulance = widget.initial?.hasAmbulance ?? false;
  late bool _ambulanceAvailable = widget.initial?.ambulanceAvailable ?? false;
  late bool _accepting = widget.initial?.acceptingReferrals ?? true;
  bool _locating = false;
  bool _saving = false;

  bool get _isCreate => widget.initial == null;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location services are turned off.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission was not granted. Enter the coordinates instead.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      _lat.text = pos.latitude.toStringAsFixed(6);
      _lng.text = pos.longitude.toStringAsFixed(6);
      if (mounted) showStaffSnack(context, 'Location set from GPS.');
    } catch (e) {
      if (mounted) showStaffSnack(context, e is String ? e : "Couldn't get your location. Enter the coordinates instead.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (name.length < 2) {
      showStaffSnack(context, 'Enter the hospital name.');
      return;
    }
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      showStaffSnack(context, 'Set the map location: use GPS or enter a valid latitude and longitude.');
      return;
    }
    final input = Facility(
      name: name,
      address: _address.text.trim(),
      phoneNumber: _phone.text.trim(),
      latitude: lat,
      longitude: lng,
      hasEmergencyRoom: _er,
      hasAmbulance: _ambulance,
      ambulanceAvailable: _ambulanceAvailable,
      acceptingReferrals: _accepting,
    );
    setState(() => _saving = true);
    final api = ref.read(hospitalApiProvider);
    final r = await runPortalAction(
      context,
      () => _isCreate ? api.createHospital(input) : api.updateHospital(input),
      success: _isCreate ? null : 'Facility profile saved.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r == null) return;
    if (_isCreate) {
      ref.invalidate(staffAccessProvider);
    } else {
      ref.invalidate(myHospitalProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          PortalHeader(
            title: _isCreate ? 'Create your hospital' : 'Facility profile',
            subtitle: _isCreate
                ? 'Patients see this in the VitaNet app when choosing where to send their summary.'
                : 'This feeds the patient app’s nearest A&E list.',
            onBack: _isCreate ? null : () => Navigator.of(context).pop(),
            trailing: _isCreate
                ? HeaderIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'Sign out',
                    onPressed: () => confirmAndSignOut(context, ref),
                  )
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                StaffContent(
                  maxWidth: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StaffCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PortalTextField(
                                controller: _name,
                                label: 'Hospital name',
                                hint: 'Ridge Regional Hospital',
                                capitalization: TextCapitalization.words),
                            const SizedBox(height: 14),
                            PortalTextField(controller: _address, label: 'Address', hint: 'Castle Rd, Accra'),
                            const SizedBox(height: 14),
                            PortalTextField(
                                controller: _phone,
                                label: 'Phone number',
                                hint: '+233 30 222 8382',
                                keyboardType: TextInputType.phone),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      StaffCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Map location', style: staffBody(13, weight: FontWeight.w600, color: p.ink)),
                            const SizedBox(height: 4),
                            Text('Stand at the hospital entrance and use GPS, or type the coordinates.',
                                style: staffBody(12, color: p.muted)),
                            const SizedBox(height: 12),
                            StaffButton('Use my current location',
                                kind: StaffButtonKind.secondary,
                                icon: Icons.my_location_rounded,
                                loading: _locating,
                                onPressed: _useGps),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: PortalTextField(
                                      controller: _lat,
                                      label: 'Latitude',
                                      hint: '5.5600',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true, signed: true)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PortalTextField(
                                      controller: _lng,
                                      label: 'Longitude',
                                      hint: '-0.2000',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true, signed: true)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      StaffGroup(children: [
                        StaffSwitchRow(
                          title: 'Emergency room',
                          subtitle: 'Has an A&E / emergency department',
                          icon: Icons.emergency_outlined,
                          iconTone: StaffTone.danger,
                          value: _er,
                          onChanged: (v) => setState(() => _er = v),
                        ),
                        StaffSwitchRow(
                          title: 'Ambulance service',
                          icon: Icons.airport_shuttle_outlined,
                          iconTone: StaffTone.amber,
                          value: _ambulance,
                          onChanged: (v) => setState(() => _ambulance = v),
                        ),
                        if (_ambulance)
                          StaffSwitchRow(
                            title: 'Ambulance available now',
                            value: _ambulanceAvailable,
                            onChanged: (v) => setState(() => _ambulanceAvailable = v),
                          ),
                        StaffSwitchRow(
                          title: 'Accepting VitaNet referrals',
                          subtitle: 'Patients can send their triage summary here',
                          icon: Icons.move_to_inbox_outlined,
                          value: _accepting,
                          onChanged: (v) => setState(() => _accepting = v),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      StaffButton(_isCreate ? 'Create hospital' : 'Save changes', loading: _saving, onPressed: _save),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
