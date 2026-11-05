import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/widgets/profile_completion_banner.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Single-page medical profile editor.
///
/// [initialTab] ('personal' | 'medical' | 'lifestyle' | 'emergency') scrolls
/// to the matching section on open.
class EditProfileScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  const EditProfileScreen({super.key, this.initialTab});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _sexOptions = ['Female', 'Male', 'Other'];
  static const _commonConditions = [
    'Asthma', 'Hypertension', 'Diabetes Type 2', 'Migraine', 'Arthritis',
    'High Cholesterol', 'Anxiety', 'Depression', 'Thyroid Disorder', 'COPD',
  ];
  static const _allergenSuggestions = [
    'Penicillin', 'Sulfa Drugs', 'Aspirin / NSAIDs', 'Peanuts', 'Latex', 'Shellfish',
    'Codeine / Opioids', 'Dairy / Eggs',
  ];
  static const _medicationSuggestions = [
    'Daily Multivitamin', 'Lisinopril 10mg', 'Metformin 500mg', 'Atorvastatin 20mg',
    'Salbutamol inhaler 100 mcg', 'Levothyroxine 50mcg',
  ];
  static const _familySuggestions = [
    'Heart Disease', 'Type 2 Diabetes', 'Hypertension', 'Stroke', 'Breast Cancer',
    'Colorectal Cancer', "Alzheimer's / Dementia", 'Asthma',
  ];
  static const _exerciseOptions = ['Never', 'Sometimes', 'Mostly'];
  static const _relationOptions = ['Family', 'Partner', 'Parent', 'Sibling', 'Friend', 'Doctor', 'Other'];

  final _scroll = ScrollController();
  final _personalKey = GlobalKey();
  final _medicalKey = GlobalKey();
  final _lifestyleKey = GlobalKey();
  final _emergencyKey = GlobalKey();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  DateTime? _dob;
  String? _rawDob;
  String? _sex;
  String? _bloodType;
  late List<String> _allergies;
  late List<String> _medications;
  late List<String> _conditions;
  late List<String> _family;
  bool _smoking = false;
  bool _alcohol = false;
  String? _exercise;
  late List<EmergencyContact> _contacts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pr = ref.read(userProfileProvider);
    _name = TextEditingController(text: pr?.name ?? '');
    _phone = TextEditingController(text: pr?.phone ?? '');
    String fmt(double? v) =>
        v == null ? '' : (v.truncateToDouble() == v ? v.toInt().toString() : v.toString());
    _height = TextEditingController(text: fmt(pr?.height));
    _weight = TextEditingController(text: fmt(pr?.weight));
    final raw = pr?.dob?.trim();
    if (raw != null && raw.isNotEmpty) {
      _dob = DateTime.tryParse(raw);
      if (_dob == null) {
        try {
          _dob = DateFormat('MMMM d, yyyy').parse(raw);
        } catch (_) {
          _rawDob = raw;
        }
      }
    }
    _sex = pr?.sex;
    _bloodType = pr?.bloodType;
    _allergies = List.of(pr?.allergies ?? const []);
    _medications = List.of(pr?.medications ?? const []);
    _conditions = List.of(pr?.preExistingConditions ?? const []);
    _family = List.of(pr?.familyMedicalHistory ?? const []);
    _smoking = pr?.smoking ?? false;
    _alcohol = pr?.alcohol ?? false;
    _exercise = pr?.exerciseFrequency;
    _contacts = List.of(pr?.emergencyContacts ?? const []);

    final target = switch (widget.initialTab) {
      'medical' => _medicalKey,
      'lifestyle' => _lifestyleKey,
      'emergency' => _emergencyKey,
      _ => null,
    };
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = target.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _phone.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  UserProfile _build(UserProfile? current) {
    int? age;
    final d = _dob;
    if (d != null) {
      final now = DateTime.now();
      age = now.year - d.year - ((now.month < d.month || (now.month == d.month && now.day < d.day)) ? 1 : 0);
    }
    return (current ?? UserProfile(name: _name.text.trim())).copyWith(
      name: _name.text.trim(),
      age: age ?? current?.age,
      sex: _sex,
      preExistingConditions: _conditions,
      allergies: _allergies,
      bloodType: _bloodType,
      phone: _phone.text.trim(),
      dob: d != null ? DateFormat('yyyy-MM-dd').format(d) : _rawDob,
      height: double.tryParse(_height.text.trim()),
      weight: double.tryParse(_weight.text.trim()),
      medications: _medications,
      familyMedicalHistory: _family,
      smoking: _smoking,
      alcohol: _alcohol,
      exerciseFrequency: _exercise,
      emergencyContacts: _contacts,
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      context.showSnack('Please enter your name');
      return;
    }
    setState(() => _saving = true);
    await ref.read(userProfileProvider.notifier).updateProfile(_build(ref.read(userProfileProvider)));
    if (!mounted) return;
    setState(() => _saving = false);
    context.showSnack('Medical profile saved');
    if (context.canPop()) context.pop();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  /// Text-entry dialog with optional quick-pick suggestions.
  Future<String?> _askText({
    required String title,
    required String hint,
    String initial = '',
    List<String> suggestions = const [],
  }) async {
    final ctrl = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnDialog(children: [
          Text(title, style: VnText.heading(20, color: p.ink)),
          VnTextField(
            controller: ctrl,
            hint: hint,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          if (suggestions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in suggestions)
                  VnChip(
                    label: s,
                    height: 36,
                    fontSize: 13,
                    onTap: () => Navigator.pop(ctx, s),
                  ),
              ],
            ),
          Row(children: [
            Expanded(
              child: VnOutlineButton(
                label: 'Cancel',
                background: p.surfaceAlt,
                borderColor: Colors.transparent,
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VnButton(label: 'Save', height: 52, onPressed: () => Navigator.pop(ctx, ctrl.text)),
            ),
          ]),
        ]);
      },
    );
    ctrl.dispose();
    final v = res?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _editContact([int? index]) async {
    final existing = index == null ? null : _contacts[index];
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final infoCtrl = TextEditingController(
        text: existing == null ? '' : (existing.phone.isNotEmpty ? existing.phone : (existing.email ?? '')));
    var relation = existing?.relation ?? 'Family';
    final result = await showVnSheet<EmergencyContact?>(
      context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final p = VnPalette.of(ctx);
        return VnSheet(children: [
          Text(existing == null ? 'Add contact' : 'Edit contact',
              style: VnText.heading(20, color: p.ink)),
          VnTextField(label: 'Full name', controller: nameCtrl, hint: 'e.g. Chidi Okafor'),
          VnTextField(
            label: 'Phone or email',
            controller: infoCtrl,
            hint: '+234 803 555 0142',
            keyboardType: TextInputType.emailAddress,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in {..._relationOptions, relation})
                VnChip(
                  label: r,
                  height: 38,
                  selected: relation == r,
                  onTap: () => setS(() => relation = r),
                ),
            ],
          ),
          VnButton(
            label: existing == null ? 'Add to care circle' : 'Update contact',
            onPressed: () {
              final n = nameCtrl.text.trim();
              final i = infoCtrl.text.trim();
              if (n.isEmpty || i.isEmpty) return;
              Navigator.pop(
                ctx,
                EmergencyContact(
                  name: n,
                  phone: i.contains('@') ? '' : i,
                  email: i.contains('@') ? i : null,
                  relation: relation,
                ),
              );
            },
          ),
        ]);
      }),
    );
    nameCtrl.dispose();
    infoCtrl.dispose();
    if (result != null) {
      setState(() {
        if (index == null) {
          _contacts.add(result);
        } else {
          _contacts[index] = result;
        }
      });
    }
  }

  // ── UI helpers ──

  Widget _label(VnPalette p, String t) =>
      Text(t, style: VnText.body(13, weight: FontWeight.w600, color: p.ink));

  Widget _field(VnPalette p, String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_label(p, label), const SizedBox(height: 6), child],
      );

  InputDecoration _dec(VnPalette p, {String? hint, String? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: VnText.body(15, color: p.faint),
        suffixText: suffix,
        suffixStyle: VnText.body(15, color: p.muted),
        filled: true,
        fillColor: p.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.brand, width: 2),
        ),
      );

  Widget _section(VnPalette p, String title, List<Widget> children, {Key? key, Widget? trailing}) =>
      Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: VnSectionLabel(title, padding: EdgeInsets.zero)),
            ?trailing,
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );

  Widget _removableChip(VnPalette p, String label, VoidCallback onRemove, {bool warm = false}) {
    final fg = p.isDark
        ? const Color(0xFFFCA5A5)
        : (warm ? const Color(0xFF9A3412) : const Color(0xFF991B1B));
    final bg = p.isDark
        ? const Color(0xFF3B1414)
        : (warm ? const Color(0xFFFFEDD5) : const Color(0xFFFEE2E2));
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12, right: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: VnText.body(14, weight: FontWeight.w600, color: fg)),
        IconButton(
          tooltip: 'Remove $label',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 16, color: fg),
          onPressed: onRemove,
        ),
      ]),
    );
  }

  Widget _addChip(VnPalette p, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: p.line),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: onTap,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 16, color: p.inkSoft),
                const SizedBox(width: 6),
                Text(label, style: VnText.body(14, weight: FontWeight.w600, color: p.inkSoft)),
              ]),
            ),
          ),
        ),
      );

  Widget _toggleChip(VnPalette p, String label, bool on, VoidCallback onTap) => Semantics(
        button: true,
        selected: on,
        child: Material(
          color: on ? p.brandTint : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: on ? p.brand : p.line),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(label,
                  style: VnText.body(14,
                      weight: on ? FontWeight.w700 : FontWeight.w600,
                      color: on ? p.brandDeep : p.ink)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final pct = ProfileCompletionBanner.completion(_build(ref.watch(userProfileProvider)));
    final complete = (pct * 100).round();
    final dob = _dob;

    final h = double.tryParse(_height.text.trim());
    final w = double.tryParse(_weight.text.trim());
    final bmi = (h != null && w != null && h > 0 && w > 0) ? w / ((h / 100) * (h / 100)) : null;

    final conditionOptions = {..._commonConditions, ..._conditions}.toList();

    return Scaffold(
      backgroundColor: p.page,
      body: Column(
        children: [
          // Top bar
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.line)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  VnIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Back',
                    iconSize: 26,
                    onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Medical profile', style: VnText.heading(19, color: p.ink))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: complete >= 100
                          ? p.tintBg(const Color(0xFFD1FAE5), const Color(0xFF047857))
                          : p.tintBg(const Color(0xFFFEF3C7), const Color(0xFF92400E)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$complete% complete',
                        style: VnText.body(12,
                            weight: FontWeight.w700,
                            color: p.tintFg(complete >= 100
                                ? const Color(0xFF047857)
                                : const Color(0xFF92400E)))),
                  ),
                ]),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _section(p, 'Personal', key: _personalKey, [
                      VnTextField(label: 'Full name', controller: _name, hint: 'Your name'),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: _field(
                            p,
                            'Phone',
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              style: VnText.body(15, color: p.ink),
                              decoration: _dec(p, hint: '+234 …'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            p,
                            'Date of birth',
                            Semantics(
                              button: true,
                              label: 'Date of birth',
                              child: Material(
                                color: p.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: p.line),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _pickDob,
                                  child: Container(
                                    height: 50,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      dob != null
                                          ? DateFormat('d MMM yyyy').format(dob)
                                          : (_rawDob ?? 'Select'),
                                      style: VnText.body(15,
                                          color: dob == null && _rawDob == null ? p.faint : p.ink),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                      _field(
                        p,
                        'Sex',
                        VnSegmented(
                          height: 48,
                          options: _sexOptions,
                          index: _sex == null ? -1 : _sexOptions.indexOf(_sex!),
                          onChanged: (i) => setState(() => _sex = _sexOptions[i]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _section(p, 'Body', key: _medicalKey, [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: _field(
                            p,
                            'Height',
                            TextField(
                              controller: _height,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              onChanged: (_) => setState(() {}),
                              style: VnText.body(15, color: p.ink),
                              decoration: _dec(p, suffix: 'cm'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            p,
                            'Weight',
                            TextField(
                              controller: _weight,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              onChanged: (_) => setState(() {}),
                              style: VnText.body(15, color: p.ink),
                              decoration: _dec(p, suffix: 'kg'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            p,
                            'Blood type',
                            DropdownButtonFormField<String>(
                              initialValue: _bloodTypes.contains(_bloodType) ? _bloodType : null,
                              isExpanded: true,
                              dropdownColor: p.surface,
                              borderRadius: BorderRadius.circular(14),
                              style: VnText.body(15, color: p.ink),
                              decoration: _dec(p, hint: '--'),
                              items: [
                                for (final b in _bloodTypes)
                                  DropdownMenuItem(value: b, child: Text(b)),
                              ],
                              onChanged: (v) => setState(() => _bloodType = v),
                            ),
                          ),
                        ),
                      ]),
                      if (bmi != null)
                        Text(
                          'BMI ${bmi.toStringAsFixed(1)} · ${bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Healthy range' : bmi < 30 ? 'Overweight' : 'Obese range'}',
                          style: VnText.body(13, color: p.muted),
                        ),
                    ]),
                    const SizedBox(height: 22),
                    _section(p, 'Allergies', [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (var i = 0; i < _allergies.length; i++)
                          _removableChip(p, _allergies[i],
                              () => setState(() => _allergies.removeAt(i)), warm: i.isOdd),
                        _addChip(p, 'Add', () async {
                          final v = await _askText(
                            title: 'Add allergy',
                            hint: 'e.g. Penicillin · severe',
                            suggestions: _allergenSuggestions.where((s) => !_allergies.contains(s)).toList(),
                          );
                          if (v != null && !_allergies.contains(v)) setState(() => _allergies.add(v));
                        }),
                      ]),
                    ]),
                    const SizedBox(height: 22),
                    _section(
                      p,
                      'Medications',
                      trailing: VnLink(
                        label: '+ Add',
                        fontSize: 13,
                        weight: FontWeight.w700,
                        onTap: () async {
                          final v = await _askText(
                            title: 'Add medication',
                            hint: 'Name, strength and how often',
                            suggestions:
                                _medicationSuggestions.where((s) => !_medications.contains(s)).toList(),
                          );
                          if (v != null && !_medications.contains(v)) setState(() => _medications.add(v));
                        },
                      ),
                      [
                        if (_medications.isEmpty)
                          Text('No medications added.', style: VnText.body(14, color: p.muted))
                        else
                          VnListGroup(radius: 18, children: [
                            for (var i = 0; i < _medications.length; i++)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                                child: Row(children: [
                                  VnIconTile(
                                    icon: Icons.medication_outlined,
                                    bg: i.isEven ? const Color(0xFFEDE9FE) : const Color(0xFFE0F2FE),
                                    fg: i.isEven ? const Color(0xFF6D28D9) : const Color(0xFF0369A1),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(_medications[i],
                                        style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
                                  ),
                                  VnIconButton(
                                    icon: Icons.edit_outlined,
                                    tooltip: 'Edit ${_medications[i]}',
                                    iconSize: 20,
                                    foreground: p.muted,
                                    onPressed: () async {
                                      final v = await _askText(
                                        title: 'Edit medication',
                                        hint: 'Name, strength and how often',
                                        initial: _medications[i],
                                      );
                                      if (v != null) setState(() => _medications[i] = v);
                                    },
                                  ),
                                  VnIconButton(
                                    icon: Icons.delete_outline_rounded,
                                    tooltip: 'Remove ${_medications[i]}',
                                    iconSize: 20,
                                    foreground: p.muted,
                                    onPressed: () => setState(() => _medications.removeAt(i)),
                                  ),
                                ]),
                              ),
                          ]),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _section(p, 'Conditions & history', [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final c in conditionOptions)
                          _toggleChip(p, c, _conditions.contains(c), () => setState(() =>
                              _conditions.contains(c) ? _conditions.remove(c) : _conditions.add(c))),
                        _addChip(p, 'Other', () async {
                          final v = await _askText(title: 'Add condition', hint: 'e.g. Epilepsy');
                          if (v != null && !_conditions.contains(v)) setState(() => _conditions.add(v));
                        }),
                      ]),
                      _label(p, 'Family medical history'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final f in _family)
                          _toggleChip(p, f, true, () => setState(() => _family.remove(f))),
                        _addChip(p, 'Add', () async {
                          final v = await _askText(
                            title: 'Family medical history',
                            hint: 'e.g. Heart disease (father)',
                            suggestions: _familySuggestions.where((s) => !_family.contains(s)).toList(),
                          );
                          if (v != null && !_family.contains(v)) setState(() => _family.add(v));
                        }),
                      ]),
                    ]),
                    const SizedBox(height: 22),
                    _section(p, 'Lifestyle', key: _lifestyleKey, [
                      VnListGroup(radius: 18, children: [
                        VnListRow(
                          title: 'Smoking',
                          subtitle: 'Any tobacco or vaping',
                          chevron: false,
                          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                          onTap: () => setState(() => _smoking = !_smoking),
                          trailing: VnSwitch(
                            value: _smoking,
                            semanticLabel: 'Smoking',
                            onChanged: (v) => setState(() => _smoking = v),
                          ),
                        ),
                        VnListRow(
                          title: 'Alcohol',
                          subtitle: 'More than 2 drinks a week',
                          chevron: false,
                          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                          onTap: () => setState(() => _alcohol = !_alcohol),
                          trailing: VnSwitch(
                            value: _alcohol,
                            semanticLabel: 'Alcohol',
                            onChanged: (v) => setState(() => _alcohol = v),
                          ),
                        ),
                      ]),
                      _field(
                        p,
                        'Exercise',
                        VnSegmented(
                          options: _exerciseOptions,
                          index: _exercise == null ? -1 : _exerciseOptions.indexOf(_exercise!),
                          onChanged: (i) => setState(() => _exercise = _exerciseOptions[i]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _section(
                      p,
                      'Care circle',
                      key: _emergencyKey,
                      trailing: VnLink(
                        label: '+ Add',
                        fontSize: 13,
                        weight: FontWeight.w700,
                        onTap: () => _editContact(),
                      ),
                      [
                        if (_contacts.isEmpty)
                          Text('No emergency contacts yet.', style: VnText.body(14, color: p.muted))
                        else
                          VnListGroup(radius: 18, children: [
                            for (var i = 0; i < _contacts.length; i++)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                                child: Row(children: [
                                  VnAvatar(name: _contacts[i].name, size: 40, fontSize: 14),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_contacts[i].name,
                                            style: VnText.body(15, weight: FontWeight.w600, color: p.ink)),
                                        Text(
                                          '${_contacts[i].relation} · ${_contacts[i].phone.isNotEmpty ? _contacts[i].phone : (_contacts[i].email ?? '')}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: VnText.body(12, color: p.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  VnIconButton(
                                    icon: Icons.edit_outlined,
                                    tooltip: 'Edit ${_contacts[i].name}',
                                    iconSize: 20,
                                    foreground: p.muted,
                                    onPressed: () => _editContact(i),
                                  ),
                                  VnIconButton(
                                    icon: Icons.delete_outline_rounded,
                                    tooltip: 'Remove ${_contacts[i].name}',
                                    iconSize: 20,
                                    foreground: p.muted,
                                    onPressed: () => setState(() => _contacts.removeAt(i)),
                                  ),
                                ]),
                              ),
                          ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sticky save bar
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: VnButton(label: 'Save changes', loading: _saving, onPressed: _save),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
