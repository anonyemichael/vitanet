import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

class _TempContact {
  final String name;
  final String contactInfo; // Email or phone
  final String relation;
  final bool isPrimary;

  const _TempContact({
    required this.name,
    required this.contactInfo,
    required this.relation,
    required this.isPrimary,
  });

  _TempContact copyWith({bool? isPrimary}) => _TempContact(
        name: name,
        contactInfo: contactInfo,
        relation: relation,
        isPrimary: isPrimary ?? this.isPrimary,
      );
}

/// Three-step profile setup after first sign-in:
/// 1. About you, 2. Health basics, 3. Care circle.
class PatientCompletionScreen extends ConsumerStatefulWidget {
  const PatientCompletionScreen({super.key});

  @override
  ConsumerState<PatientCompletionScreen> createState() =>
      _PatientCompletionScreenState();
}

class _PatientCompletionScreenState
    extends ConsumerState<PatientCompletionScreen> {
  static const _stepNames = ['About you', 'Health basics', 'Care circle'];
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _conditionOptions = [
    'Asthma',
    'Hypertension',
    'Type 2 diabetes',
    'Pregnant or breastfeeding',
  ];
  static const _relationOptions = ['Family', 'Friend', 'Partner', 'Doctor', 'Other'];

  int _step = 0;

  // Step 1
  final _aboutFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 2
  DateTime? _dob;
  String? _sex;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _bloodType;
  final List<String> _allergies = [];
  final Set<String> _conditions = {};
  final _medsController = TextEditingController();

  // Step 3
  final _contactNameController = TextEditingController();
  final _contactInfoController = TextEditingController();
  String _selectedRelation = 'Family';
  final List<_TempContact> _careCircle = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    try {
      if (Firebase.apps.isNotEmpty) {
        _nameController.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medsController.dispose();
    _contactNameController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  // ── Care circle helpers (kept from the original flow) ──

  void _addContactToCircle() {
    if (_contactNameController.text.trim().isEmpty ||
        _contactInfoController.text.trim().isEmpty) {
      context.showSnack('Please enter name and contact info');
      return;
    }
    setState(() {
      _careCircle.add(_TempContact(
        name: _contactNameController.text.trim(),
        contactInfo: _contactInfoController.text.trim(),
        relation: _selectedRelation,
        isPrimary: _careCircle.isEmpty,
      ));
      _contactNameController.clear();
      _contactInfoController.clear();
      _selectedRelation = 'Family';
    });
  }

  void _removeContact(int index) {
    setState(() {
      _careCircle.removeAt(index);
      if (_careCircle.isNotEmpty && !_careCircle.any((c) => c.isPrimary)) {
        _careCircle[0] = _careCircle[0].copyWith(isPrimary: true);
      }
    });
  }

  void _setPrimary(int index) {
    setState(() {
      for (var i = 0; i < _careCircle.length; i++) {
        _careCircle[i] = _careCircle[i].copyWith(isPrimary: i == index);
      }
    });
  }

  Future<void> _addAllergy() async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnDialog(children: [
          Text('Add allergy', style: VnText.heading(20, color: p.ink)),
          VnTextField(
            controller: ctrl,
            hint: 'e.g. Penicillin',
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(ctx, v),
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
              child: VnButton(
                label: 'Add',
                height: 52,
                onPressed: () => Navigator.pop(ctx, ctrl.text),
              ),
            ),
          ]),
        ]);
      },
    );
    ctrl.dispose();
    final v = value?.trim() ?? '';
    if (v.isNotEmpty && !_allergies.contains(v)) {
      setState(() => _allergies.add(v));
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  // ── Navigation ──

  void _continue() {
    HapticFeedback.lightImpact();
    if (_step == 0) {
      if (!(_aboutFormKey.currentState?.validate() ?? false)) return;
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_dob == null) {
        context.showSnack('Please add your date of birth');
        return;
      }
      if (_sex == null) {
        context.showSnack('Please select sex at birth');
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_careCircle.isEmpty) {
      context.showSnack('Please add at least one emergency contact, or tap Skip');
      return;
    }
    _save();
  }

  void _skip() {
    if (_step == 0) {
      if (!(_aboutFormKey.currentState?.validate() ?? false)) return;
      setState(() => _step = 1);
    } else if (_step == 1) {
      setState(() => _step = 2);
    } else {
      _save();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step -= 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login/patient');
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final currentUser =
          Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;

      final contacts = _careCircle
          .map((c) => EmergencyContact(
                name: c.name,
                phone: c.contactInfo.contains('@') ? '' : c.contactInfo,
                email: c.contactInfo.contains('@') ? c.contactInfo : null,
                relation: c.relation,
              ))
          .toList();
      // Primary contact first so alerts use it.
      final primary = _careCircle.indexWhere((c) => c.isPrimary);
      if (primary > 0) contacts.insert(0, contacts.removeAt(primary));

      final dob = _dob;
      final today = DateTime.now();
      final age = dob == null
          ? null
          : today.year -
              dob.year -
              ((today.month < dob.month ||
                      (today.month == dob.month && today.day < dob.day))
                  ? 1
                  : 0);

      final meds = _medsController.text
          .split(RegExp(r'[,\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final name = _nameController.text.trim();
      final profile = UserProfile(
        name: name.isNotEmpty ? name : (currentUser?.displayName ?? 'Patient'),
        age: age,
        role: 'user',
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        dob: dob == null ? null : '${dob.year}-${_two(dob.month)}-${_two(dob.day)}',
        sex: _sex,
        height: double.tryParse(_heightController.text.trim()),
        weight: double.tryParse(_weightController.text.trim()),
        bloodType: _bloodType,
        allergies: List.of(_allergies),
        preExistingConditions: _conditions.toList(),
        medications: meds,
        emergencyContacts: contacts,
      );

      await ref.read(userProfileProvider.notifier).updateProfile(profile);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) context.showSnack('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.page,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildHeader(p),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _buildAboutStep(p),
                            1 => _buildHealthStep(p),
                            _ => _buildCareStep(p),
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Row(
                      children: [
                        VnOutlineButton(
                          label: 'Skip',
                          expand: false,
                          height: 56,
                          background: p.surfaceAlt,
                          borderColor: Colors.transparent,
                          onPressed: _isLoading ? null : _skip,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: VnButton(
                            label: _step == 2 ? 'Finish setup' : 'Continue',
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _continue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(VnPalette p) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          VnIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Back',
            iconSize: 26,
            bordered: true,
            onPressed: _back,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Step ${_step + 1} of 3 · ${_stepNames[_step]}',
                    style: VnText.body(12, weight: FontWeight.w600, color: p.muted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? p.brand
                                : (p.isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(VnPalette p, String title, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: VnText.heading(26, color: p.ink)),
          ),
          const SizedBox(height: 6),
          Text(body, style: VnText.body(15, color: p.muted, height: 1.5)),
        ],
      );

  Widget _label(VnPalette p, String text) =>
      Text(text, style: VnText.body(13, weight: FontWeight.w600, color: p.ink));

  Widget _buildAboutStep(VnPalette p) {
    return Form(
      key: _aboutFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _intro(p, 'Tell us about you',
              'Your name and number help your care circle and clinicians reach you.'),
          const SizedBox(height: 20),
          VnTextField(
            label: 'Full name',
            controller: _nameController,
            hint: 'e.g. Amara Okafor',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          VnTextField(
            label: 'Phone number',
            controller: _phoneController,
            hint: '+234 801 234 5678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final s = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if (s.isEmpty) return 'Please enter your phone number';
              if (s.length < 7) return 'Enter a valid phone number';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _unitField(VnPalette p, String label, TextEditingController c, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(p, label),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: VnText.body(15, color: p.ink, weight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: p.surface,
            suffixText: unit,
            suffixStyle: VnText.body(15, color: p.muted, weight: FontWeight.w500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: p.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: p.brand, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthStep(VnPalette p) {
    final dob = _dob;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intro(p, 'A few health basics',
            'VitaNet uses this to tailor advice, like flagging medicines that clash with your allergies.'),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(p, 'Date of birth'),
                  const SizedBox(height: 6),
                  Semantics(
                    button: true,
                    label: 'Date of birth',
                    child: Material(
                      color: p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: p.line),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickDob,
                        child: Container(
                          height: 52,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            dob == null
                                ? 'DD / MM / YYYY'
                                : '${_two(dob.day)} / ${_two(dob.month)} / ${dob.year}',
                            style: VnText.body(15,
                                color: dob == null ? p.faint : p.ink,
                                weight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(p, 'Sex at birth'),
                  const SizedBox(height: 6),
                  VnSegmented(
                    height: 52,
                    options: const ['Female', 'Male'],
                    index: _sex == 'Male' ? 1 : (_sex == 'Female' ? 0 : -1),
                    onChanged: (i) => setState(() => _sex = i == 0 ? 'Female' : 'Male'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _unitField(p, 'Height', _heightController, 'cm')),
            const SizedBox(width: 12),
            Expanded(child: _unitField(p, 'Weight', _weightController, 'kg')),
          ],
        ),
        const SizedBox(height: 20),
        _label(p, 'Blood type'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final t in _bloodTypes)
              Semantics(
                button: true,
                selected: _bloodType == t,
                label: 'Blood type $t',
                excludeSemantics: true,
                child: Material(
                  color: _bloodType == t ? p.brand : p.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _bloodType == t ? p.brand : p.line),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _bloodType = t),
                    child: Center(
                      child: Text(t,
                          style: VnText.body(15,
                              weight: FontWeight.w700,
                              color: _bloodType == t ? p.onBrand : p.ink)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _label(p, 'Allergies'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _allergies) _AllergyChip(label: a, onRemove: () => setState(() => _allergies.remove(a))),
            _DashedAddChip(label: 'Add allergy', onTap: _addAllergy),
          ],
        ),
        const SizedBox(height: 20),
        _label(p, 'Ongoing conditions'),
        const SizedBox(height: 10),
        VnListGroup(
          children: [
            for (final c in _conditionOptions)
              InkWell(
                onTap: () => setState(() =>
                    _conditions.contains(c) ? _conditions.remove(c) : _conditions.add(c)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _conditions.contains(c),
                        activeColor: p.brand,
                        checkColor: p.onBrand,
                        side: BorderSide(color: p.faint, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        onChanged: (v) => setState(() =>
                            v == true ? _conditions.add(c) : _conditions.remove(c)),
                      ),
                      const SizedBox(width: 2),
                      Expanded(child: Text(c, style: VnText.body(15, color: p.ink))),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        VnTextField(
          label: 'Current medications',
          controller: _medsController,
          hint: 'e.g. Salbutamol inhaler 100 mcg, as needed',
        ),
      ],
    );
  }

  Widget _buildCareStep(VnPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intro(p, 'Your care circle',
            'If a check comes back urgent, these people get notified with your location.'),
        const SizedBox(height: 20),
        if (_careCircle.isNotEmpty) ...[
          VnListGroup(
            children: [
              for (var i = 0; i < _careCircle.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      VnAvatar(name: _careCircle[i].name, size: 44, fontSize: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_careCircle[i].name,
                                style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                            Text(
                              '${_careCircle[i].relation} · ${_careCircle[i].contactInfo}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: VnText.body(13, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                      if (_careCircle[i].isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.brandTint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Primary',
                              style: VnText.body(12, weight: FontWeight.w700, color: p.brandDeep)),
                        )
                      else
                        VnIconButton(
                          icon: Icons.star_outline_rounded,
                          tooltip: 'Make ${_careCircle[i].name} primary',
                          foreground: p.muted,
                          onPressed: () => _setPrimary(i),
                        ),
                      VnIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Remove ${_careCircle[i].name}',
                        foreground: p.muted,
                        onPressed: () => _removeContact(i),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        VnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a contact',
                  style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
              const SizedBox(height: 14),
              VnTextField(
                label: 'Name',
                controller: _contactNameController,
                hint: 'e.g. Chidi Okafor',
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              VnTextField(
                label: 'Phone or email',
                controller: _contactInfoController,
                hint: '+234 801 234 5678',
                prefixIcon: Icons.call_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _label(p, 'Relationship'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _relationOptions)
                    VnChip(
                      label: r,
                      selected: _selectedRelation == r,
                      onTap: () => setState(() => _selectedRelation = r),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              VnOutlineButton(
                label: 'Add to care circle',
                icon: Icons.add_rounded,
                foreground: p.brand,
                borderColor: p.brandBorder,
                background: p.brandWash,
                onPressed: _addContactToCircle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllergyChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _AllergyChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final fg = p.isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 14, right: 2),
      decoration: BoxDecoration(
        color: p.dangerTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: VnText.body(14, weight: FontWeight.w600, color: fg)),
          IconButton(
            tooltip: 'Remove $label',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: Icon(Icons.close_rounded, size: 16, color: fg),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _DashedAddChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DashedAddChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedStadiumPainter(p.faint),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: p.inkSoft),
                const SizedBox(width: 6),
                Text(label, style: VnText.body(14, weight: FontWeight.w600, color: p.inkSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedStadiumPainter extends CustomPainter {
  final Color color;
  _DashedStadiumPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    ).deflate(0.5);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter old) => old.color != color;
}
