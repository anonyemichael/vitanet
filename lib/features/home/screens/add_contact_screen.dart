import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/widgets/care_circle_section.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Care circle manager: current contacts plus an "Add someone new" form.
class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  static const _relations = ['Family', 'Partner', 'Doctor', 'Friend'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'Family';
  bool _alertOnUrgent = true;
  bool _weeklySummary = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final currentProfile = ref.read(userProfileProvider);
    if (currentProfile == null) {
      context.showSnack('Create your profile first to add contacts');
      return;
    }
    final info = _phoneController.text.trim();
    final isEmail = info.contains('@');
    final newContact = EmergencyContact(
      name: _nameController.text.trim(),
      phone: isEmail ? '' : info,
      email: isEmail ? info : null,
      relation: _selectedRole,
    );

    final updated = List<EmergencyContact>.from(currentProfile.emergencyContacts)
      ..add(newContact);
    await ref
        .read(userProfileProvider.notifier)
        .updateProfile(currentProfile.copyWith(emergencyContacts: updated));

    try {
      final auth = ref.read(authProvider);
      final userId = auth.user?.uid ?? '';
      await ref.read(apiServiceProvider).addCareCircleMember(
        userId: userId,
        fullName: newContact.name,
        relationship: _selectedRole.toLowerCase(),
        contactEmail: newContact.email,
        contactPhone: newContact.phone.isNotEmpty ? newContact.phone : null,
        isPrimary: _alertOnUrgent,
      );
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('care_alert_$info', _alertOnUrgent);
      await prefs.setBool('care_weekly_$info', _weeklySummary);
    } catch (_) {}

    if (!mounted) return;
    context.showSnack(isEmail
        ? 'Invitation sent to ${newContact.name}'
        : '${newContact.name} added to your care circle');
    _nameController.clear();
    _phoneController.clear();
    setState(() {
      _selectedRole = 'Family';
      _alertOnUrgent = true;
      _weeklySummary = false;
    });
  }

  Future<void> _removeContact(int index) async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;
    final updated = List<EmergencyContact>.from(profile.emergencyContacts)..removeAt(index);
    await ref
        .read(userProfileProvider.notifier)
        .updateProfile(profile.copyWith(emergencyContacts: updated));
  }

  void _contactActions(int index, EmergencyContact c) {
    showVnSheet<void>(
      context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnSheet(
          children: [
            Text(c.name, style: VnText.heading(20, color: p.ink)),
            VnListGroup(
              children: [
                if (c.phone.trim().isNotEmpty)
                  VnListRow(
                    leading: const VnIconTile(
                        icon: Icons.call_outlined, bg: Color(0xFFD1FAE5), fg: Color(0xFF047857)),
                    title: 'Call ${c.name.split(' ').first}',
                    subtitle: c.phone,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final uri = Uri.parse('tel:${c.phone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                VnListRow(
                  leading: const VnIconTile(
                      icon: Icons.person_remove_outlined,
                      bg: Color(0xFFFEE2E2),
                      fg: Color(0xFFB91C1C)),
                  title: 'Remove from care circle',
                  titleColor: p.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeContact(index);
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final contacts = ref.watch(userProfileProvider)?.emergencyContacts ?? const <EmergencyContact>[];

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        VnIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Text('Care circle',
                              textAlign: TextAlign.center,
                              style: VnText.heading(20, color: p.ink)),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (contacts.isEmpty)
                    VnCard(
                      child: Row(
                        children: [
                          const VnIconTile(
                            icon: Icons.group_outlined,
                            bg: Color(0xFFDBEAFE),
                            fg: Color(0xFF1E40AF),
                            size: 42,
                            radius: 21,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No contacts yet. People you add are alerted if a check comes back urgent.',
                              style: VnText.body(14, color: p.muted, height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    VnListGroup(
                      children: [
                        for (var i = 0; i < contacts.length; i++)
                          InkWell(
                            onTap: () => _contactActions(i, contacts[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  VnAvatar(
                                    name: contacts[i].name,
                                    size: 42,
                                    fontSize: 14,
                                    bg: careCircleAvatarColors[i % careCircleAvatarColors.length].$1,
                                    fg: careCircleAvatarColors[i % careCircleAvatarColors.length].$2,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(contacts[i].name,
                                            style: VnText.body(15,
                                                weight: FontWeight.w600, color: p.ink)),
                                        Text(
                                          '${contacts[i].relation} · ${contacts[i].phone.isNotEmpty ? contacts[i].phone : (contacts[i].email ?? '')}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: VnText.body(13, color: p.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusPill(active: contacts[i].phone.trim().isNotEmpty),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 22),
                  Semantics(
                    header: true,
                    child: Text('Add someone new',
                        style: VnText.heading(18, weight: FontWeight.w700, color: p.ink)),
                  ),
                  const SizedBox(height: 18),
                  VnTextField(
                    label: 'Full name',
                    controller: _nameController,
                    hint: 'e.g. Dr. Funmi Bello',
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 18),
                  VnTextField(
                    label: 'Phone or email',
                    controller: _phoneController,
                    hint: '+234 809 555 0121',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Enter a phone number or email';
                      if (s.contains('@')) return s.contains('.') ? null : 'Enter a valid email';
                      return s.replaceAll(RegExp(r'[^0-9]'), '').length < 7
                          ? 'Enter a valid phone number'
                          : null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Text('Relationship',
                      style: VnText.body(13, weight: FontWeight.w600, color: p.ink)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in _relations)
                        _OutlinedChoice(
                          label: r,
                          selected: _selectedRole == r,
                          onTap: () => setState(() => _selectedRole = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  VnListGroup(
                    children: [
                      VnListRow(
                        title: 'Alert on urgent results',
                        subtitle: 'SMS with your location',
                        chevron: false,
                        onTap: () => setState(() => _alertOnUrgent = !_alertOnUrgent),
                        trailing: VnSwitch(
                          value: _alertOnUrgent,
                          semanticLabel: 'Alert on urgent results',
                          onChanged: (v) => setState(() => _alertOnUrgent = v),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                      ),
                      VnListRow(
                        title: 'Share weekly vitals summary',
                        subtitle: 'Every Sunday, by email',
                        chevron: false,
                        onTap: () => setState(() => _weeklySummary = !_weeklySummary),
                        trailing: VnSwitch(
                          value: _weeklySummary,
                          semanticLabel: 'Share weekly vitals summary',
                          onChanged: (v) => setState(() => _weeklySummary = v),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  VnButton(
                    label: 'Send invitation',
                    icon: Icons.send_rounded,
                    onPressed: _saveContact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final fg = active ? const Color(0xFF047857) : const Color(0xFFB45309);
    final bg = active ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.tintBg(bg, fg),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(active ? 'Active' : 'Invited',
          style: VnText.body(12, weight: FontWeight.w700, color: p.tintFg(fg))),
    );
  }
}

class _OutlinedChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OutlinedChoice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.brandTint : p.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? p.brand : p.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label,
                style: VnText.body(14,
                    weight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? p.brandDeep : p.ink)),
          ),
        ),
      ),
    );
  }
}
