import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/providers/portal_providers.dart';
import 'package:vitanet/features/admin/screens/portal_shell.dart';
import 'package:vitanet/features/admin/widgets/portal_common.dart';
import 'package:vitanet/features/admin/widgets/staff_ui.dart';

/// Hospital (design): bed occupancy, equipment grid, who is on duty now.
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
    final hospitalName = ref.watch(myHospitalProvider).valueOrNull?.name;
    final now = TimeOfDay.now();
    final live = 'live at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    Widget addButton(String label, VoidCallback onPressed) => TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(label),
        );

    return Column(
      children: [
        PortalHeader(
          title: 'Hospital',
          subtitle: hospitalName == null ? live : '$hospitalName · $live',
          onBack: onBack,
        ),
        Expanded(
          child: PortalAsyncList<Capacity>(
            value: value,
            onRefresh: () => ref.refresh(capacityProvider.future),
            builder: (cap) {
              final onDuty = cap.team.where((m) => m.onDuty).toList();
              return [
                _Panel(
                  title: 'Bed occupancy',
                  action: isAdmin ? addButton('Add ward', () => _open(context, ref, const WardSheet(isAdmin: true))) : null,
                  child: cap.wards.isEmpty
                      ? PortalEmpty(
                          icon: Icons.bed_outlined,
                          title: 'No wards set up yet',
                          message: isAdmin
                              ? 'Add your wards and bed counts so staff can place patients.'
                              : 'Your administrator hasn’t added wards yet.',
                        )
                      : Column(
                          children: [
                            for (final w in cap.wards)
                              _WardRow(ward: w, onTap: () => _open(context, ref, WardSheet(isAdmin: isAdmin, ward: w))),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'Equipment',
                  action: isAdmin
                      ? addButton('Add', () => _open(context, ref, const EquipmentSheet(isAdmin: true)))
                      : null,
                  child: cap.equipment.isEmpty
                      ? const PortalEmpty(icon: Icons.medical_services_outlined, title: 'No equipment listed')
                      : LayoutBuilder(builder: (context, c) {
                          final w = (c.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final e in cap.equipment)
                                SizedBox(
                                  width: w,
                                  child: _EquipmentTile(
                                    equipment: e,
                                    onTap: () => _open(context, ref, EquipmentSheet(isAdmin: isAdmin, equipment: e)),
                                  ),
                                ),
                            ],
                          );
                        }),
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'On duty now · ${onDuty.length}',
                  child: onDuty.isEmpty
                      ? PortalEmpty(
                          icon: Icons.badge_outlined,
                          title: 'Nobody is marked on duty',
                          message: 'Staff switch themselves on shift from Home.',
                        )
                      : Column(children: [for (final m in onDuty) TeamMemberTile(member: m)]),
                ),
                if (cap.team.length > onDuty.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 4),
                    child: Text('${cap.team.length - onDuty.length} more off shift',
                        style: staffBody(13, color: p.muted)),
                  ),
              ];
            },
          ),
        ),
      ],
    );
  }
}

/// White rounded section card with a heading and optional action.
class _Panel extends StatelessWidget {
  final String title;
  final Widget? action;
  final Widget child;
  const _Panel({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: staffHeading(18, weight: FontWeight.w700, color: p.ink)),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _WardRow extends StatelessWidget {
  final Ward ward;
  final VoidCallback onTap;
  const _WardRow({required this.ward, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final ratio = ward.bedsTotal == 0 ? 0.0 : ward.bedsOccupied / ward.bedsTotal;
    final color = ratio >= 0.9
        ? const Color(0xFFDC2626)
        : ratio >= 0.7
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
    return Semantics(
      button: true,
      label: '${ward.name}: ${ward.bedsOccupied} of ${ward.bedsTotal} beds occupied, ${ward.bedsFree} free. Edit',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(ward.name, style: staffBody(15, weight: FontWeight.w600, color: p.ink)),
                  ),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: '${ward.bedsOccupied}',
                        style: staffBody(14, weight: FontWeight.w800, color: p.ink)),
                    TextSpan(
                        text: ' / ${ward.bedsTotal} · ${ward.bedsFree} free',
                        style: staffBody(14, color: p.muted)),
                  ])),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: p.line,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  final Equipment equipment;
  final VoidCallback onTap;
  const _EquipmentTile({required this.equipment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = StaffPalette.of(context);
    final e = equipment;
    final tone = e.available == 0
        ? StaffTone.danger
        : (e.total > 0 && e.available / e.total < 0.5)
            ? StaffTone.amber
            : StaffTone.neutral;
    final t = p.tone(tone);
    final accent = tone == StaffTone.neutral ? p.tone(StaffTone.green).fg : t.fg;
    return StaffTap(
      onTap: onTap,
      color: tone == StaffTone.neutral ? p.bg : t.bg,
      radius: 18,
      semanticLabel: '${e.name}: ${e.available} of ${e.total} free${(e.note ?? '').isEmpty ? '' : ', ${e.note}'}. Edit',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: staffBody(13, weight: FontWeight.w600, color: tone == StaffTone.neutral ? p.muted : t.fg)),
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${e.available}', style: staffHeading(24, color: p.ink)),
              TextSpan(
                  text: ' of ${e.total} free',
                  style: staffBody(13, weight: FontWeight.w700, color: accent)),
            ])),
            if ((e.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(e.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: staffBody(12, color: p.muted)),
            ],
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
