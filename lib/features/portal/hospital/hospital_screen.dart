import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/hospital/admin_pages.dart';
import 'package:vitanet/features/portal/shell/portal_nav.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

/// Beds by ward, equipment, who is on shift — and, for admins, the
/// accepting switch, team requests, hospital profile and activity log.
class HospitalScreen extends ConsumerWidget {
  const HospitalScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Widget sheet) async {
    final changed = await showCSheet<bool>(context, builder: (_) => sheet);
    if (changed == true) {
      ref.invalidate(capacityProvider);
      ref.invalidate(dashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final me = ref.watch(staffAccessProvider).valueOrNull?.me;
    final admin = me?.isAdmin ?? false;
    final hospital = ref.watch(myHospitalProvider).valueOrNull;
    final dash = ref.watch(dashboardProvider).valueOrNull;
    final value = ref.watch(capacityProvider);
    final desk = isDesk(context);

    return RefreshIndicator(
      color: p.primary,
      onRefresh: () async {
        ref.invalidate(myHospitalProvider);
        ref.invalidate(dashboardProvider);
        await ref.refresh(capacityProvider.future).then((_) {});
      },
      child: value.when(
        loading: () => ListView(children: const [CLoading()]),
        error: (e, _) => ListView(children: [CError(error: e, onRetry: () => ref.invalidate(capacityProvider))]),
        data: (cap) {
          final onShift = cap.team.where((m) => m.onDuty).toList()
            ..sort((a, b) => b.activeCases.compareTo(a.activeCases));
          final beds = _BedsPanel(
            wards: cap.wards,
            admin: admin,
            onAdd: () => _edit(context, ref, const WardSheet()),
            onEdit: (w) => _edit(context, ref, WardSheet(ward: w)),
          );
          final equipment = _EquipmentPanel(
            equipment: cap.equipment,
            admin: admin,
            onAdd: () => _edit(context, ref, EquipmentSheet(admin: admin)),
            onEdit: (e) => _edit(context, ref, EquipmentSheet(admin: admin, equipment: e)),
          );
          final team = _OnShiftPanel(onShift: onShift, offShift: cap.team.length - onShift.length);
          final adminLinks = admin ? _AdminLinks(pendingStaff: dash?.counts.pendingStaff ?? 0) : null;
          final accepting = _AcceptingCard(
            accepting: dash?.acceptingReferrals ?? hospital?.acceptingReferrals ?? true,
            admin: admin,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('Hospital', style: cText(26, weight: FontWeight.w700, color: p.ink, letterSpacing: -0.2)),
              Text('${hospital?.name ?? ''}${hospital == null ? '' : ' · '}live', style: cText(13, color: p.muted)),
              const SizedBox(height: 12),
              if (desk)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: Column(children: [accepting, const SizedBox(height: 12), beds])),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(children: [
                        equipment,
                        const SizedBox(height: 12),
                        team,
                        if (adminLinks != null) ...[const SizedBox(height: 12), adminLinks],
                      ]),
                    ),
                  ],
                )
              else ...[
                accepting,
                const SizedBox(height: 12),
                beds,
                const SizedBox(height: 12),
                equipment,
                const SizedBox(height: 12),
                team,
                if (adminLinks != null) ...[
                  const SizedBox(height: 12),
                  adminLinks,
                  const SizedBox(height: 8),
                  Text('Only admins see the switch, the editors and this last group.', style: cText(12, color: p.muted)),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AcceptingCard extends ConsumerWidget {
  final bool accepting;
  final bool admin;
  const _AcceptingCard({required this.accepting, required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ClinicalPalette.of(context);
    final title = accepting ? 'Accepting VitaNet patients' : 'Paused — not accepting';
    final sub = accepting
        ? 'Patients nearby can send their summary here.'
        : 'VitaNet sends new patients to other hospitals.';
    return CCard(
      color: accepting ? null : p.tone(Tone.orange).bg,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: cText(15, weight: FontWeight.w600, color: p.ink)),
                Text(admin ? sub : '$sub Only an admin can change this.', style: cText(12, color: p.muted)),
              ],
            ),
          ),
          if (admin)
            CSwitch(
              value: accepting,
              onChanged: (v) async {
                final res = await runCAction(context, () => ref.read(hospitalApiProvider).setAccepting(v),
                    success: v ? 'Accepting VitaNet patients.' : 'Paused — VitaNet is sending patients elsewhere.');
                if (res != null) {
                  ref.invalidate(dashboardProvider);
                  ref.invalidate(myHospitalProvider);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget? action;
  final Widget child;
  const _Panel({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) => CCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 36, child: CSectionLabel(title, trailing: action)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

Widget _linkButton(BuildContext context, String label, VoidCallback onTap) => TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
      child: Text(label, style: cText(13, weight: FontWeight.w600, color: ClinicalPalette.of(context).primary)),
    );

class _BedsPanel extends StatelessWidget {
  final List<Ward> wards;
  final bool admin;
  final VoidCallback onAdd;
  final ValueChanged<Ward> onEdit;
  const _BedsPanel({required this.wards, required this.admin, required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return _Panel(
      title: 'Beds',
      action: admin ? _linkButton(context, 'Add ward', onAdd) : null,
      child: wards.isEmpty
          ? CEmpty(
              icon: Icons.bed_outlined,
              title: 'No wards yet',
              message: admin ? 'Add your wards and bed counts so staff can place patients.' : 'An admin adds wards here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final w in wards)
                  InkWell(
                    onTap: admin ? () => onEdit(w) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Semantics(
                        label: '${w.name}: ${w.bedsFree} of ${w.bedsTotal} beds free',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(child: Text(w.name, style: cText(15, weight: FontWeight.w600, color: p.ink))),
                                Text(w.bedsFree == 0 ? 'Full' : '${w.bedsFree} free',
                                    style: cMono(14, color: w.bedsFree == 0 ? p.tone(Tone.red).fg : p.ink)),
                                Text('  of ${w.bedsTotal}', style: cMono(12, weight: FontWeight.w500, color: p.muted)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: w.bedsTotal == 0 ? 0 : (w.bedsOccupied / w.bedsTotal).clamp(0, 1).toDouble(),
                                minHeight: 6,
                                backgroundColor: p.track,
                                color: p.tone(w.bedsFree == 0
                                        ? Tone.red
                                        : (w.bedsTotal > 0 && w.bedsOccupied / w.bedsTotal >= 0.7 ? Tone.orange : Tone.green))
                                    .dot,
                              ),
                            ),
                            if (w.patients.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                w.patients.length <= 3
                                    ? w.patients.join(', ')
                                    : '${w.patients.take(2).join(', ')} and ${w.patients.length - 2} more',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: cText(12, color: p.muted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text('Counts follow patients: accepting, moving and discharging update them for you.',
                    style: cText(12, color: p.muted)),
              ],
            ),
    );
  }
}

class _EquipmentPanel extends StatelessWidget {
  final List<Equipment> equipment;
  final bool admin;
  final VoidCallback onAdd;
  final ValueChanged<Equipment> onEdit;
  const _EquipmentPanel({required this.equipment, required this.admin, required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return _Panel(
      title: 'Equipment',
      action: admin ? _linkButton(context, 'Add', onAdd) : null,
      child: equipment.isEmpty
          ? const CEmpty(icon: Icons.medical_services_outlined, title: 'No equipment listed')
          : LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in equipment)
                    SizedBox(
                      width: w,
                      child: Builder(builder: (context) {
                        final tone = e.available == 0
                            ? Tone.red
                            : (e.total > 0 && e.available / e.total < 0.34 ? Tone.orange : null);
                        final t = tone == null ? null : p.tone(tone);
                        return Material(
                          color: t?.bg ?? p.bg,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onEdit(e),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: cText(12, weight: FontWeight.w600, color: t?.fg ?? p.muted)),
                                  Text.rich(TextSpan(children: [
                                    TextSpan(text: '${e.available}', style: cMono(18, color: t?.fg ?? p.ink)),
                                    TextSpan(text: ' of ${e.total} free', style: cText(12, color: t?.fg ?? p.muted)),
                                  ])),
                                  if ((e.note ?? '').isNotEmpty)
                                    Text(e.note!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: cText(11, color: t?.fg ?? p.muted)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              );
            }),
    );
  }
}

class _OnShiftPanel extends StatelessWidget {
  final List<TeamMember> onShift;
  final int offShift;
  const _OnShiftPanel({required this.onShift, required this.offShift});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return _Panel(
      title: 'On shift now · ${onShift.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onShift.isEmpty) Text('Nobody is on shift. Staff switch themselves on from the Board.', style: cText(13, color: p.muted)),
          for (final m in onShift)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CAvatar(m.fullName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.fullName, style: cText(14, weight: FontWeight.w600, color: p.ink)),
                        Text([m.role.label, if ((m.department ?? '').isNotEmpty) m.department!].join(' · '),
                            style: cText(12, color: p.muted)),
                      ],
                    ),
                  ),
                  Text('${m.activeCases} patient${m.activeCases == 1 ? '' : 's'}', style: cText(12, color: p.muted)),
                ],
              ),
            ),
          if (offShift > 0)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('$offShift off shift', style: cText(12, color: p.muted))),
        ],
      ),
    );
  }
}

class _AdminLinks extends StatelessWidget {
  final int pendingStaff;
  const _AdminLinks({required this.pendingStaff});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    Widget row(String title, String? sub, Widget page, {int badge = 0, bool last = false}) => Column(
          children: [
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: cText(15, weight: FontWeight.w600, color: p.ink))),
                    if (sub != null) Text(sub, style: cText(12, color: p.muted)),
                    if (badge > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: p.tone(Tone.red).dot, borderRadius: BorderRadius.circular(11)),
                        alignment: Alignment.center,
                        child: Text('$badge', style: cMono(12, color: Colors.white)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, color: p.faint),
                  ],
                ),
              ),
            ),
            if (!last) Divider(height: 1, color: p.divider),
          ],
        );
    return CCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          row('Team & join requests', null, const TeamPage(), badge: pendingStaff),
          row('Hospital profile', 'Address, phone, services', const FacilityFormPage()),
          row('Activity log', 'Who did what', const AuditPage(), last: true),
        ],
      ),
    );
  }
}

// ─── Editors ───

class WardSheet extends ConsumerStatefulWidget {
  final Ward? ward;
  const WardSheet({super.key, this.ward});

  @override
  ConsumerState<WardSheet> createState() => _WardSheetState();
}

class _WardSheetState extends ConsumerState<WardSheet> {
  late final _name = TextEditingController(text: widget.ward?.name ?? '');
  late final _total = TextEditingController(text: '${widget.ward?.bedsTotal ?? ''}');
  late final _occupied = TextEditingController(text: '${widget.ward?.bedsOccupied ?? 0}');
  late bool _critical = widget.ward?.critical ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _total.dispose();
    _occupied.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final total = int.tryParse(_total.text.trim());
    final occupied = int.tryParse(_occupied.text.trim()) ?? 0;
    if (_name.text.trim().isEmpty || total == null) {
      showCSnack(context, 'Add a name and how many beds the ward has.');
      return;
    }
    if (occupied > total) {
      showCSnack(context, "Occupied beds can't be more than the total.");
      return;
    }
    final input = WardInput(name: _name.text.trim(), bedsTotal: total, bedsOccupied: occupied, critical: _critical);
    final api = ref.read(hospitalApiProvider);
    setState(() => _saving = true);
    final ok = await runCAction(
      context,
      () async {
        widget.ward == null ? await api.addWard(input) : await api.updateWard(widget.ward!.id, input);
        return true;
      },
      success: widget.ward == null ? 'Ward added.' : 'Ward updated.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final yes = await confirmC(context,
        title: 'Remove ${widget.ward!.name}?',
        message: 'Only possible when no patients are in it.',
        confirm: 'Remove',
        danger: true);
    if (!yes || !mounted) return;
    final ok = await runCAction(context, () async {
      await ref.read(hospitalApiProvider).deleteWard(widget.ward!.id);
      return true;
    }, success: 'Ward removed.');
    if (ok == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return CSheet(
      title: widget.ward == null ? 'Add a ward' : 'Edit ${widget.ward!.name}',
      gap: 14,
      actions: [
        if (widget.ward != null) CButton('Remove', kind: CButtonKind.secondary, onPressed: _delete),
        CButton('Save', loading: _saving, onPressed: _save),
      ],
      children: [
        CTextField(controller: _name, label: 'Name', hint: 'e.g. Resus', capitalization: TextCapitalization.words),
        Row(children: [
          Expanded(child: CTextField(controller: _total, label: 'Total beds', mono: true, keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: CTextField(controller: _occupied, label: 'Occupied now', mono: true, keyboardType: TextInputType.number)),
        ]),
        Text(
          'Occupied beds normally follow patients. Change it here only to correct the count — the change is logged.',
          style: cText(12, color: p.muted),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Critical care', style: cText(15, weight: FontWeight.w600, color: p.ink)),
                  Text('Resus, ICU, HDU — suggested for the sickest patients', style: cText(12, color: p.muted)),
                ],
              ),
            ),
            CSwitch(value: _critical, onChanged: (v) => setState(() => _critical = v)),
          ],
        ),
      ],
    );
  }
}

class EquipmentSheet extends ConsumerStatefulWidget {
  final Equipment? equipment;
  final bool admin;
  const EquipmentSheet({super.key, this.equipment, required this.admin});

  @override
  ConsumerState<EquipmentSheet> createState() => _EquipmentSheetState();
}

class _EquipmentSheetState extends ConsumerState<EquipmentSheet> {
  late final _name = TextEditingController(text: widget.equipment?.name ?? '');
  late final _total = TextEditingController(text: '${widget.equipment?.total ?? ''}');
  late final _note = TextEditingController(text: widget.equipment?.note ?? '');
  late int _available = widget.equipment?.available ?? 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _total.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _totalValue => int.tryParse(_total.text.trim()) ?? widget.equipment?.total ?? 0;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _totalValue <= 0) {
      showCSnack(context, 'Add a name and how many there are.');
      return;
    }
    final input = EquipmentInput(
        name: _name.text.trim(), available: _available.clamp(0, _totalValue), total: _totalValue, note: _note.text.trim());
    final api = ref.read(hospitalApiProvider);
    setState(() => _saving = true);
    final ok = await runCAction(context, () async {
      widget.equipment == null ? await api.addEquipment(input) : await api.updateEquipment(widget.equipment!.id, input);
      return true;
    }, success: 'Saved.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final yes = await confirmC(context,
        title: 'Remove ${widget.equipment!.name}?', message: 'It will no longer be listed.', confirm: 'Remove', danger: true);
    if (!yes || !mounted) return;
    final ok = await runCAction(context, () async {
      await ref.read(hospitalApiProvider).deleteEquipment(widget.equipment!.id);
      return true;
    }, success: 'Removed.');
    if (ok == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    final canEditDetails = widget.admin;
    final total = _totalValue;
    return CSheet(
      title: widget.equipment == null ? 'Add equipment' : widget.equipment!.name,
      subtitle: canEditDetails ? null : 'Update how many are free right now.',
      gap: 14,
      actions: [
        if (widget.equipment != null && canEditDetails) CButton('Remove', kind: CButtonKind.secondary, onPressed: _delete),
        CButton('Save', loading: _saving, onPressed: _save),
      ],
      children: [
        if (canEditDetails) ...[
          CTextField(controller: _name, label: 'Name', hint: 'e.g. Ventilators', capitalization: TextCapitalization.words),
          CTextField(controller: _total, label: 'How many in total', mono: true, keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {})),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CSectionLabel('Free right now'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CIconButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'One fewer',
                  outlined: true,
                  onPressed: _available > 0 ? () => setState(() => _available--) : null,
                ),
                SizedBox(
                  width: 120,
                  child: Text('$_available of $total', textAlign: TextAlign.center, style: cMono(22, color: p.ink)),
                ),
                CIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'One more',
                  outlined: true,
                  onPressed: _available < total ? () => setState(() => _available++) : null,
                ),
              ],
            ),
          ],
        ),
        CTextField(controller: _note, label: 'Note (optional)', hint: 'e.g. CT in use till 10:40'),
      ],
    );
  }
}
