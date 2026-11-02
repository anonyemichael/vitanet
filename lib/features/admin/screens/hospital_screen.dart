import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/portal_shell.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Hospital capacity: wards, equipment, team on duty.
class HospitalScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  const HospitalScreen({super.key, this.onBack});

  Future<void> _open(BuildContext context, WidgetRef ref, Widget sheet) async {
    final changed = await showStaffSheet<bool>(context, tall: true, builder: (_) => sheet);
    if (changed == true) {
      ref.invalidate(capacityProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = StaffPalette.of(context);
    final isAdmin = ref.watch(portalMeProvider)?.isAdmin ?? false;
    final value = ref.watch(capacityProvider);
    return Column(
      children: [
        PortalHeader(title: 'Hospital', subtitle: 'Beds, equipment and who is on duty', onBack: onBack),
        Expanded(
          child: PortalAsyncList<Capacity>(
            value: value,
            onRefresh: () => ref.refresh(capacityProvider.future),
            builder: (cap) {
              final onDuty = cap.team.where((m) => m.onDuty).toList();
              final beds = cap.wards.fold<int>(0, (s, w) => s + w.bedsTotal);
              final used = cap.wards.fold<int>(0, (s, w) => s + w.bedsOccupied);
              return [
                PortalSectionTitle(
                  'Wards',
                  trailing: isAdmin
                      ? TextButton.icon(
                          onPressed: () => _open(context, ref, const WardSheet(isAdmin: true)),
                          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add ward'),
                        )
                      : null,
                ),
                if (cap.wards.isEmpty)
                  StaffCard(
                    child: PortalEmpty(
                      icon: Icons.bed_outlined,
                      title: 'No wards set up yet',
                      message: isAdmin
                          ? 'Add your wards and bed counts so staff can place patients.'
                          : 'Your administrator hasn’t added wards yet.',
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('${beds - used} of $beds beds free', style: staffBody(13, color: p.muted)),
                  ),
                  for (final w in cap.wards) ...[
                    _CapacityCard(
                      title: w.name,
                      used: w.bedsOccupied,
                      total: w.bedsTotal,
                      caption: '${w.bedsOccupied}/${w.bedsTotal} beds occupied · ${w.bedsFree} free',
                      critical: w.critical,
                      onTap: () => _open(context, ref, WardSheet(isAdmin: isAdmin, ward: w)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                PortalSectionTitle(
                  'Equipment',
                  trailing: isAdmin
                      ? TextButton.icon(
                          onPressed: () => _open(context, ref, const EquipmentSheet(isAdmin: true)),
                          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add'),
                        )
                      : null,
                ),
                if (cap.equipment.isEmpty)
                  const StaffCard(
                    child: PortalEmpty(icon: Icons.medical_services_outlined, title: 'No equipment listed'),
                  )
                else
                  for (final e in cap.equipment) ...[
                    _CapacityCard(
                      title: e.name,
                      used: e.total - e.available,
                      total: e.total,
                      caption: '${e.available}/${e.total} available${(e.note ?? '').isEmpty ? '' : ' · ${e.note}'}',
                      onTap: () => _open(context, ref, EquipmentSheet(isAdmin: isAdmin, equipment: e)),
                    ),
                    const SizedBox(height: 10),
                  ],
                PortalSectionTitle('On duty now (${onDuty.length})'),
                if (onDuty.isEmpty)
                  const StaffCard(
                    child: PortalEmpty(
                      icon: Icons.badge_outlined,
                      title: 'Nobody is marked on duty',
                      message: 'Staff switch themselves on duty from the Today screen.',
                    ),
                  )
                else
                  StaffGroup(children: [for (final m in onDuty) TeamMemberTile(member: m)]),
                if (cap.team.length > onDuty.length) ...[
                  PortalSectionTitle('Off duty (${cap.team.length - onDuty.length})'),
                  StaffGroup(children: [for (final m in cap.team.where((m) => !m.onDuty)) TeamMemberTile(member: m)]),
                ],
              ];
            },
          ),
        ),
      ],
    );
  }
}

class _CapacityCard extends StatelessWidget {
  final String title;
  final int used;
  final int total;
  final String caption;
  final bool critical;
  final VoidCallback onTap;

  const _CapacityCard({
    required this.title,
    required this.used,
    required this.total,
    required this.caption,
    required this.onTap,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return StaffTap(
      onTap: onTap,
      color: p.card,
      radius: 16,
      semanticLabel: '$title, $caption. Edit',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: staffBody(15, weight: FontWeight.w700, color: p.ink))),
                if (critical) ...[const StaffTag('Critical care', tone: StaffTone.danger), const SizedBox(width: 6)],
                Icon(Icons.edit_outlined, size: 18, color: p.faint),
              ],
            ),
            const SizedBox(height: 10),
            OccupancyBar(used: used, total: total),
            const SizedBox(height: 6),
            Text(caption, style: staffBody(12, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

/// Add / edit a ward. Non-admins can only change occupied beds.
class WardSheet extends ConsumerStatefulWidget {
  final bool isAdmin;
  final Ward? ward;
  const WardSheet({super.key, required this.isAdmin, this.ward});

  @override
  ConsumerState<WardSheet> createState() => _WardSheetState();
}

class _WardSheetState extends ConsumerState<WardSheet> {
  late final _name = TextEditingController(text: widget.ward?.name);
  late int _total = widget.ward?.bedsTotal ?? 10;
  late int _occupied = widget.ward?.bedsOccupied ?? 0;
  late bool _critical = widget.ward?.critical ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showStaffSnack(context, 'Enter the ward name.');
      return;
    }
    final input = WardInput(name: name, bedsTotal: _total, bedsOccupied: _occupied, critical: _critical);
    final api = ref.read(hospitalApiProvider);
    setState(() => _saving = true);
    final ok = await runPortalAction(context, () async {
      if (widget.ward == null) {
        await api.addWard(input);
      } else {
        await api.updateWard(widget.ward!.id, input);
      }
      return true;
    }, success: 'Ward saved.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final yes = await confirmPortal(context,
        title: 'Delete ${widget.ward!.name}?',
        message: 'The ward must be empty. This can’t be undone.',
        confirm: 'Delete',
        destructive: true);
    if (!yes || !mounted) return;
    final ok = await runPortalAction(context, () async {
      await ref.read(hospitalApiProvider).deleteWard(widget.ward!.id);
      return true;
    }, success: 'Ward deleted.');
    if (ok == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.isAdmin;
    return PortalSheet(
      title: widget.ward == null ? 'Add ward' : (admin ? 'Edit ward' : 'Update occupancy'),
      subtitle: admin || widget.ward == null ? null : widget.ward!.name,
      actions: [
        if (admin && widget.ward != null)
          StaffButton('Delete', kind: StaffButtonKind.dangerOutline, onPressed: _saving ? null : _delete)
        else
          StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Save', loading: _saving, onPressed: _save),
      ],
      children: [
        if (admin) ...[
          PortalTextField(controller: _name, label: 'Ward name', hint: 'Emergency', capitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          CountStepper(
            label: 'Total beds',
            value: _total,
            min: 0,
            onChanged: (v) => setState(() {
              _total = v;
              if (_occupied > _total) _occupied = _total;
            }),
          ),
          const SizedBox(height: 8),
        ],
        CountStepper(
          label: 'Occupied beds',
          value: _occupied,
          max: _total,
          onChanged: (v) => setState(() => _occupied = v),
        ),
        const SizedBox(height: 8),
        OccupancyBar(used: _occupied, total: _total),
        if (admin) ...[
          const SizedBox(height: 10),
          StaffGroup(children: [
            StaffSwitchRow(
              title: 'Critical care ward',
              value: _critical,
              onChanged: (v) => setState(() => _critical = v),
            ),
          ]),
        ],
      ],
    );
  }
}

/// Add / edit equipment. Non-admins can only change the available count.
class EquipmentSheet extends ConsumerStatefulWidget {
  final bool isAdmin;
  final Equipment? equipment;
  const EquipmentSheet({super.key, required this.isAdmin, this.equipment});

  @override
  ConsumerState<EquipmentSheet> createState() => _EquipmentSheetState();
}

class _EquipmentSheetState extends ConsumerState<EquipmentSheet> {
  late final _name = TextEditingController(text: widget.equipment?.name);
  late final _note = TextEditingController(text: widget.equipment?.note);
  late int _total = widget.equipment?.total ?? 1;
  late int _available = widget.equipment?.available ?? 1;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showStaffSnack(context, 'Enter the equipment name.');
      return;
    }
    final input = EquipmentInput(name: name, available: _available, total: _total, note: _note.text.trim());
    final api = ref.read(hospitalApiProvider);
    setState(() => _saving = true);
    final ok = await runPortalAction(context, () async {
      if (widget.equipment == null) {
        await api.addEquipment(input);
      } else {
        await api.updateEquipment(widget.equipment!.id, input);
      }
      return true;
    }, success: 'Equipment saved.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final yes = await confirmPortal(context,
        title: 'Delete ${widget.equipment!.name}?',
        message: 'This removes it from the capacity list.',
        confirm: 'Delete',
        destructive: true);
    if (!yes || !mounted) return;
    final ok = await runPortalAction(context, () async {
      await ref.read(hospitalApiProvider).deleteEquipment(widget.equipment!.id);
      return true;
    }, success: 'Equipment deleted.');
    if (ok == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.isAdmin;
    return PortalSheet(
      title: widget.equipment == null ? 'Add equipment' : (admin ? 'Edit equipment' : 'Update availability'),
      subtitle: admin || widget.equipment == null ? null : widget.equipment!.name,
      actions: [
        if (admin && widget.equipment != null)
          StaffButton('Delete', kind: StaffButtonKind.dangerOutline, onPressed: _saving ? null : _delete)
        else
          StaffButton('Cancel', kind: StaffButtonKind.secondary, onPressed: () => Navigator.of(context).pop()),
        StaffButton('Save', loading: _saving, onPressed: _save),
      ],
      children: [
        if (admin) ...[
          PortalTextField(controller: _name, label: 'Name', hint: 'Ventilators', capitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          CountStepper(
            label: 'Total',
            value: _total,
            onChanged: (v) => setState(() {
              _total = v;
              if (_available > _total) _available = _total;
            }),
          ),
          const SizedBox(height: 8),
        ],
        CountStepper(
          label: 'Available',
          value: _available,
          max: _total,
          onChanged: (v) => setState(() => _available = v),
        ),
        const SizedBox(height: 14),
        PortalTextField(controller: _note, label: 'Note (optional)', hint: '1 in maintenance'),
      ],
    );
  }
}
