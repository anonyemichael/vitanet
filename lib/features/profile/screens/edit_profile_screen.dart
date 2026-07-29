import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';

class _ProfileEmergencyContactForm {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  String? relation;

  _ProfileEmergencyContactForm({
    required String name,
    required String phone,
    required String? email,
    required this.relation,
  })  : nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone),
        emailController = TextEditingController(text: email ?? '');

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  String? _selectedSex;
  late List<String> _selectedConditions;
  late TextEditingController _allergyController;
  late List<String> _allergies;
  String? _selectedBloodType;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _medicationController;
  late List<String> _medications;
  late TextEditingController _familyHistoryController;
  late List<String> _familyMedicalHistory;
  bool _smoking = false;
  bool _alcohol = false;
  String? _selectedExerciseFrequency;
  late List<_ProfileEmergencyContactForm> _emergencyContacts;
  final List<String> _relationOptions = ['Parent', 'Spouse', 'Child', 'Sibling', 'Friend', 'Other'];
  final List<String> _exerciseOptions = ['Never', 'Sometimes', 'Mostly'];

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _conditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Heart Disease',
    'Arthritis',
    'Depression',
    'Anxiety',
    'COPD',
    'Cancer',
    'Thyroid Disorder',
  ];
  static const _sexOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    final profile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: profile?.name ?? '');
    _ageController = TextEditingController(text: profile?.age?.toString() ?? '');
    _selectedSex = profile?.sex;
    _selectedConditions = List.from(profile?.preExistingConditions ?? []);
    _allergies = List.from(profile?.allergies ?? []);
    _allergyController = TextEditingController();
    _selectedBloodType = profile?.bloodType;
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _dobController = TextEditingController(text: profile?.dob ?? '');
    _heightController = TextEditingController(text: profile?.height?.toString() ?? '');
    _weightController = TextEditingController(text: profile?.weight?.toString() ?? '');
    _medications = List.from(profile?.medications ?? []);
    _medicationController = TextEditingController();
    _familyMedicalHistory = List.from(profile?.familyMedicalHistory ?? []);
    _familyHistoryController = TextEditingController();
    _smoking = profile?.smoking ?? false;
    _alcohol = profile?.alcohol ?? false;
    _selectedExerciseFrequency = profile?.exerciseFrequency;
    if (_selectedExerciseFrequency != null && !_exerciseOptions.contains(_selectedExerciseFrequency)) {
      _exerciseOptions.add(_selectedExerciseFrequency!);
    }
    if (profile?.emergencyContacts != null && profile!.emergencyContacts.isNotEmpty) {
      _emergencyContacts = profile.emergencyContacts.map((c) {
        if (c.relation.isNotEmpty && !_relationOptions.contains(c.relation)) {
          _relationOptions.add(c.relation);
        }
        return _ProfileEmergencyContactForm(
          name: c.name,
          phone: c.phone,
          email: c.email,
          relation: c.relation.isEmpty ? 'Other' : c.relation,
        );
      }).toList();
    } else {
      _emergencyContacts = [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _allergyController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationController.dispose();
    _familyHistoryController.dispose();
    for (var form in _emergencyContacts) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final currentProfile = ref.read(userProfileProvider);
    final profile = (currentProfile ?? UserProfile(name: _nameController.text.trim())).copyWith(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()),
      sex: _selectedSex,
      preExistingConditions: _selectedConditions,
      allergies: _allergies,
      bloodType: _selectedBloodType,
      bio: _bioController.text.trim(),
      phone: _phoneController.text.trim(),
      dob: _dobController.text.trim(),
      height: double.tryParse(_heightController.text.trim()),
      weight: double.tryParse(_weightController.text.trim()),
      medications: _medications,
      familyMedicalHistory: _familyMedicalHistory,
      smoking: _smoking,
      alcohol: _alcohol,
      exerciseFrequency: _selectedExerciseFrequency,
      emergencyContacts: _emergencyContacts.where((f) => f.nameController.text.isNotEmpty).map((f) => EmergencyContact(
        name: f.nameController.text.trim(),
        phone: f.phoneController.text.trim(),
        email: f.emailController.text.trim().isEmpty ? null : f.emailController.text.trim(),
        relation: f.relation ?? 'Other',
      )).toList(),
    );
    await ref.read(userProfileProvider.notifier).updateProfile(profile);
    if (mounted) {
      context.showSnack('Profile saved successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final bottomNavColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        elevation: 0,
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: bottomNavColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Save Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return _buildMobileLayout(context, isDark);
          } else {
            return _buildDesktopLayout(context, isDark);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isDark) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Personal'),
            Tab(text: 'Medical'),
            Tab(text: 'Lifestyle'),
            Tab(text: 'Emergency'),
          ],
          indicatorColor: context.colorScheme.primary,
          labelColor: context.colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.grey.shade500 : context.colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPersonalTab(context, isDark),
              _buildMedicalTab(context, isDark),
              _buildLifestyleTab(context, isDark),
              _buildEmergencyTab(context, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Navigation
        Container(
          width: 250,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDesktopNavItem(0, 'Personal', Icons.person_rounded, isDark),
              _buildDesktopNavItem(1, 'Medical', Icons.medical_information_rounded, isDark),
              _buildDesktopNavItem(2, 'Lifestyle', Icons.directions_run_rounded, isDark),
              _buildDesktopNavItem(3, 'Emergency', Icons.emergency_rounded, isDark),
            ],
          ),
        ),
        // Content Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: AppSpacing.xxl, bottom: AppSpacing.xxl),
            decoration: BoxDecoration(
              color: context.colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: context.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Disable swiping on desktop
                children: [
                  _wrapDesktopContent(_buildPersonalTab(context, isDark)),
                  _wrapDesktopContent(_buildMedicalTab(context, isDark)),
                  _wrapDesktopContent(_buildLifestyleTab(context, isDark)),
                  _wrapDesktopContent(_buildEmergencyTab(context, isDark)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopNavItem(int index, String title, IconData icon, bool isDark) {
    final isSelected = _tabController.index == index;
    final unselectedColor = isDark ? Colors.grey.shade500 : context.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () {
        _tabController.animateTo(index);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? context.colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? context.colorScheme.onPrimaryContainer : unselectedColor,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? context.colorScheme.onPrimaryContainer : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapDesktopContent(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: child,
      ),
    );
  }

  // --- TAB CONTENTS ---

  // --- REUSABLE CARD WIDGET ---

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required bool isDark, required List<Widget> children}) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final dividerColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  // --- TAB CONTENTS ---

  Widget _buildPersonalTab(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            context,
            title: 'Basic Information',
            icon: Icons.person_rounded,
            isDark: isDark,
            children: [
              _buildInputField('Full Name', _nameController, hint: 'Enter your name', isDark: isDark),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _buildInputField('Age', _ageController, hint: 'e.g. 30', type: TextInputType.number, isDark: isDark)),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _buildDropdownField('Sex', _sexOptions, _selectedSex, (v) => setState(() => _selectedSex = v), isDark: isDark)),
                ],
              ),
            ],
          ),
          _buildSectionCard(
            context,
            title: 'Contact Details',
            icon: Icons.contact_phone_rounded,
            isDark: isDark,
            children: [
              Row(
                children: [
                  Expanded(child: _buildInputField('Phone Number', _phoneController, hint: '+1 234 567 8900', type: TextInputType.phone, isDark: isDark)),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _buildInputField('Date of Birth', _dobController, hint: 'YYYY-MM-DD', isDark: isDark)),
                ],
              ),
            ],
          ),
          _buildSectionCard(
            context,
            title: 'Physical Metrics',
            icon: Icons.monitor_weight_rounded,
            isDark: isDark,
            children: [
              Row(
                children: [
                  Expanded(child: _buildDropdownField('Blood Type', _bloodTypes, _selectedBloodType, (v) => setState(() => _selectedBloodType = v), isDark: isDark)),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildInputField('Height (cm)', _heightController, hint: '175', type: TextInputType.number, isDark: isDark)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _buildInputField('Weight (kg)', _weightController, hint: '70', type: TextInputType.number, isDark: isDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildSectionCard(
            context,
            title: 'Additional Info',
            icon: Icons.info_outline_rounded,
            isDark: isDark,
            children: [
              _buildInputField('Bio', _bioController, hint: 'A brief description about yourself...', maxLines: 3, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalTab(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            context,
            title: 'Pre-existing Conditions',
            icon: Icons.coronavirus_rounded,
            isDark: isDark,
            children: [
              Text(
                'Select any known medical conditions you have:', 
                style: context.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _conditions.map((c) {
                  final selected = _selectedConditions.contains(c);
                  return FilterChip(
                    label: Text(
                      c, 
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected 
                            ? context.colorScheme.onPrimaryContainer 
                            : (isDark ? Colors.grey.shade300 : Colors.black87),
                      )
                    ),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) _selectedConditions.add(c);
                        else _selectedConditions.remove(c);
                      });
                    },
                    selectedColor: context.colorScheme.primaryContainer,
                    checkmarkColor: context.colorScheme.primary,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), 
                      side: BorderSide(
                        color: selected 
                            ? Colors.transparent 
                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)
                      )
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          _buildSectionCard(
            context,
            title: 'Allergies',
            icon: Icons.warning_amber_rounded,
            isDark: isDark,
            children: [
              _buildChipListField('Add an allergy', _allergyController, _allergies, _addAllergy, isDark: isDark),
            ],
          ),
          _buildSectionCard(
            context,
            title: 'Current Medications',
            icon: Icons.medication_rounded,
            isDark: isDark,
            children: [
              _buildChipListField('Add a medication', _medicationController, _medications, _addMedication, isDark: isDark),
            ],
          ),
          _buildSectionCard(
            context,
            title: 'Family Medical History',
            icon: Icons.family_restroom_rounded,
            isDark: isDark,
            children: [
              _buildChipListField('Add a family condition', _familyHistoryController, _familyMedicalHistory, _addFamilyHistory, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleTab(BuildContext context, bool isDark) {
    final dividerColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            context,
            title: 'Habits & Activity',
            icon: Icons.directions_run_rounded,
            isDark: isDark,
            children: [
              SwitchListTile(
                title: Text('Smoking', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text('Do you currently smoke?', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                value: _smoking,
                onChanged: (val) => setState(() => _smoking = val),
                contentPadding: EdgeInsets.zero,
                activeColor: context.colorScheme.primary,
              ),
              Divider(height: 1, color: dividerColor),
              SwitchListTile(
                title: Text('Alcohol', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text('Do you regularly consume alcohol?', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                value: _alcohol,
                onChanged: (val) => setState(() => _alcohol = val),
                contentPadding: EdgeInsets.zero,
                activeColor: context.colorScheme.primary,
              ),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: AppSpacing.lg),
              _buildDropdownField('Exercise Frequency', _exerciseOptions, _selectedExerciseFrequency, (v) => setState(() => _selectedExerciseFrequency = v), isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyTab(BuildContext context, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency Contacts',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _emergencyContacts.add(_ProfileEmergencyContactForm(name: '', phone: '', email: null, relation: null));
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Contact'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_emergencyContacts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.contact_phone_outlined, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No contacts added', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else
            ...List.generate(_emergencyContacts.length, (index) => _buildEmergencyContactForm(index, isDark)),
        ],
      ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildInputField(String label, TextEditingController controller, {String? hint, TextInputType type = TextInputType.text, int maxLines = 1, required bool isDark}) {
    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          style: TextStyle(color: textColor),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colorScheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, List<String> options, String? value, ValueChanged<String?> onChanged, {required bool isDark}) {
    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
          dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colorScheme.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          hint: Text('Select', style: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400)),
          items: options.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: textColor)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildChipListField(String placeholder, TextEditingController controller, List<String> items, Function(String) onAdd, {required bool isDark}) {
    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                onSubmitted: onAdd,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => onAdd(controller.text),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => Chip(
              label: Text(item, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
              deleteIcon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              onDeleted: () => setState(() => items.remove(item)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
              side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            )).toList(),
          ),
        ],
      ],
    );
  }

  void _addAllergy(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _allergies.contains(trimmed)) return;
    setState(() {
      _allergies.add(trimmed);
      _allergyController.clear();
    });
  }

  void _addMedication(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _medications.contains(trimmed)) return;
    setState(() {
      _medications.add(trimmed);
      _medicationController.clear();
    });
  }

  void _addFamilyHistory(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _familyMedicalHistory.contains(trimmed)) return;
    setState(() {
      _familyMedicalHistory.add(trimmed);
      _familyHistoryController.clear();
    });
  }

  Widget _buildEmergencyContactForm(int index, bool isDark) {
    final form = _emergencyContacts[index];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final dividerColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.shade900.withValues(alpha: 0.2) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.favorite_rounded, color: isDark ? Colors.red.shade300 : Colors.red.shade400, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Contact ${index + 1}', style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 22),
                color: isDark ? Colors.red.shade300 : Colors.red.shade400,
                onPressed: () {
                  setState(() {
                    _emergencyContacts[index].dispose();
                    _emergencyContacts.removeAt(index);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: AppSpacing.lg),
          _buildInputField('Full Name', form.nameController, hint: 'Contact name', isDark: isDark),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildInputField('Phone Number', form.phoneController, hint: '+1 234 567 8900', type: TextInputType.phone, isDark: isDark)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _buildDropdownField('Relation', _relationOptions, form.relation, (value) => setState(() => form.relation = value), isDark: isDark)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildInputField('Email Address (Optional)', form.emailController, hint: 'email@example.com', type: TextInputType.emailAddress, isDark: isDark),
        ],
      ),
    );
  }
}
