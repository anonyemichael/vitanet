import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    final text = newValue.text.replaceAll('-', '');
    if (text.length > 8) return oldValue;
    
    var newText = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 4 || i == 6) newText += '-';
      newText += text[i];
    }
    
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class _TempContact {
  final String name;
  final String contactInfo; // Email or Phone
  final String relation;
  final bool isPrimary;

  _TempContact({
    required this.name,
    required this.contactInfo,
    required this.relation,
    required this.isPrimary,
  });
}

class PatientCompletionScreen extends ConsumerStatefulWidget {
  const PatientCompletionScreen({super.key});

  @override
  ConsumerState<PatientCompletionScreen> createState() => _PatientCompletionScreenState();
}

class _PatientCompletionScreenState extends ConsumerState<PatientCompletionScreen> {
  int _currentStep = 0;
  
  // Step 1: Profile Details
  final _profileFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedSex;
  final List<String> _sexOptions = ['Male', 'Female', 'Other'];

  // Step 2: Care Circle
  final _contactNameController = TextEditingController();
  final _contactInfoController = TextEditingController();
  String _selectedRelation = 'Family';
  bool _isPrimary = false;
  final List<String> _relationOptions = ['Family', 'Friend', 'Partner', 'Doctor', 'Other'];
  
  final List<_TempContact> _careCircle = [];
  
  bool _isLoading = false;
  String _loadingText = '';

  @override
  void dispose() {
    _phoneController.dispose();
    _dobController.dispose();
    _contactNameController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  void _addContactToCircle() {
    if (_contactNameController.text.trim().isEmpty || _contactInfoController.text.trim().isEmpty) {
      context.showSnack('Please enter name and contact info');
      return;
    }
    
    setState(() {
      if (_isPrimary) {
        for (int i = 0; i < _careCircle.length; i++) {
          _careCircle[i] = _TempContact(
            name: _careCircle[i].name,
            contactInfo: _careCircle[i].contactInfo,
            relation: _careCircle[i].relation,
            isPrimary: false,
          );
        }
      } else if (_careCircle.isEmpty) {
        _isPrimary = true;
      }

      _careCircle.add(_TempContact(
        name: _contactNameController.text.trim(),
        contactInfo: _contactInfoController.text.trim(),
        relation: _selectedRelation,
        isPrimary: _isPrimary,
      ));
      
      _contactNameController.clear();
      _contactInfoController.clear();
      _selectedRelation = 'Family';
      _isPrimary = false;
    });
  }

  void _removeContact(int index) {
    setState(() {
      _careCircle.removeAt(index);
      if (_careCircle.isNotEmpty && !_careCircle.any((c) => c.isPrimary)) {
        _careCircle[0] = _TempContact(
          name: _careCircle[0].name,
          contactInfo: _careCircle[0].contactInfo,
          relation: _careCircle[0].relation,
          isPrimary: true,
        );
      }
    });
  }

  void _setPrimary(int index) {
    setState(() {
      for (int i = 0; i < _careCircle.length; i++) {
        _careCircle[i] = _TempContact(
          name: _careCircle[i].name,
          contactInfo: _careCircle[i].contactInfo,
          relation: _careCircle[i].relation,
          isPrimary: i == index,
        );
      }
    });
  }

  Future<void> _completeRegistration() async {
    if (_currentStep == 0) {
      if (!_profileFormKey.currentState!.validate()) return;
      if (_selectedSex == null) {
        context.showSnack('Please select Biological Sex');
        return;
      }
      setState(() => _currentStep = 1);
      return;
    }

    if (_currentStep == 1 && _careCircle.isEmpty) {
      context.showSnack('Please add at least one emergency contact');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingText = 'Saving Profile...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('No authenticated user found.');

      List<Map<String, dynamic>> emergencyContactsJson = [];
      List<EmergencyContact> finalContacts = [];

      for (var c in _careCircle) {
        emergencyContactsJson.add({
          "full_name": c.name,
          "contact_email": c.contactInfo.contains('@') ? c.contactInfo : null,
          "contact_number": c.contactInfo.contains('@') ? null : c.contactInfo,
          "relationship": c.relation.toLowerCase(),
          "is_primary": c.isPrimary,
        });
        
        finalContacts.add(EmergencyContact(
          name: c.name,
          phone: c.contactInfo.contains('@') ? '' : c.contactInfo,
          email: c.contactInfo.contains('@') ? c.contactInfo : null,
          relation: c.relation,
        ));
      }

      final payload = {
        "user": {
          "firebase_uid": currentUser.uid,
          "full_name": currentUser.displayName ?? 'Patient',
          "email": currentUser.email ?? '',
          "phone_number": _phoneController.text.trim(),
          "date_of_birth": _dobController.text.trim(),
          "account_type": "patient",
        },
        "care_circle": emergencyContactsJson,
      };

      await ref.read(apiServiceProvider).registerUser(payload);

      ref.read(userProfileProvider.notifier).updateProfile(
        UserProfile(
          name: currentUser.displayName ?? 'Patient',
          role: 'user', 
          phone: _phoneController.text.trim(),
          dob: _dobController.text.trim(),
          sex: _selectedSex,
          emergencyContacts: finalContacts,
        ),
      );

      if (mounted) context.go('/home'); 
    } catch (e) {
      if (mounted) context.showSnack('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep == 1 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => setState(() => _currentStep = 0),
              )
            : null,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/patient_login.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildCustomStepper(),
                          const SizedBox(height: AppSpacing.xxl),
                          
                          if (_currentStep == 0) _buildProfileDetailsStep(),
                          if (_currentStep == 1) _buildCareCircleStep(),
                          
                          const SizedBox(height: AppSpacing.xxl),
                          _buildBottomActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.health_and_safety_rounded, color: context.colorScheme.primary, size: 32),
        const SizedBox(width: AppSpacing.md),
        Text(
          _currentStep == 0 ? 'Profile Details' : 'Setup Care Circle',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomStepper() {
    return Row(
      children: [
        _buildStepIndicator(
          title: 'Account Type',
          isActive: true,
          isCompleted: true,
        ),
        _buildStepLine(isCompleted: true),
        _buildStepIndicator(
          title: 'Profile Details',
          isActive: _currentStep >= 0,
          isCompleted: _currentStep > 0,
        ),
        _buildStepLine(isCompleted: _currentStep > 0),
        _buildStepIndicator(
          title: 'Care Circle',
          isActive: _currentStep == 1,
          isCompleted: false,
        ),
      ],
    );
  }

  Widget _buildStepIndicator({required String title, required bool isActive, required bool isCompleted}) {
    final color = isCompleted ? context.colorScheme.primary : (isActive ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant.withOpacity(0.5));
    return Column(
      children: [
        Icon(
          isCompleted ? Icons.check_circle_rounded : (isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant.withOpacity(0.2),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        alignment: Alignment.topCenter,
      ),
    );
  }

  Widget _buildModernInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool isRequired = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
            children: [
              if (isRequired)
                const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: isRequired ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            prefixIcon: icon != null ? Icon(icon, color: context.colorScheme.onSurfaceVariant) : null,
            filled: true,
            fillColor: context.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetailsStep() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModernInputField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'e.g. +233 24 123 4567',
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildModernInputField(
            controller: _dobController,
            label: 'Date of Birth',
            hint: 'YYYY-MM-DD',
            keyboardType: TextInputType.number,
            inputFormatters: [_DateFormatter()],
            isRequired: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          RichText(
            text: TextSpan(
              text: 'Biological Sex',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sexOptions.map((sex) {
              final isSelected = _selectedSex == sex;
              return ChoiceChip(
                label: Text(sex, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? context.colorScheme.onPrimary : context.colorScheme.onSurface)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedSex = sex);
                },
                selectedColor: context.colorScheme.primary,
                backgroundColor: context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? Colors.transparent : context.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCareCircleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'If you trigger an SOS or request assistance, it will automatically alert these contacts, starting with your primary contact.',
            style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        
        Text('Add Contact Details', style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        
        _buildModernInputField(
          controller: _contactNameController,
          label: 'Full Name',
          hint: 'e.g. Jane Doe',
          isRequired: true,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildModernInputField(
          controller: _contactInfoController,
          label: 'Email / Phone Number *',
          hint: 'e.g. +233... or email@...',
          isRequired: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        
        RichText(
          text: TextSpan(
            text: 'Relationship',
            style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: context.colorScheme.onSurface),
            children: const [
              TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _relationOptions.map((relation) {
            final isSelected = _selectedRelation == relation;
              return ChoiceChip(
                label: Text(relation, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? context.colorScheme.onPrimary : context.colorScheme.onSurface)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedRelation = relation);
                },
                selectedColor: context.colorScheme.primary,
                backgroundColor: context.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? Colors.transparent : context.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
              );
          }).toList(),
        ),
        
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Set as Primary Contact', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('This person will be the first one alerted in an emergency.', style: TextStyle(fontSize: 12)),
          value: _isPrimary,
          onChanged: (val) => setState(() => _isPrimary = val),
          activeColor: context.colorScheme.primary,
        ),
        
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _addContactToCircle,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add to Circle', style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: context.colorScheme.primary, width: 2),
          ),
        ),
        
        if (_careCircle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Care Circle (${_careCircle.length})', style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Tap star to set primary', style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(_careCircle.length, (index) => _buildContactCard(index)),
        ],
      ],
    );
  }

  Widget _buildContactCard(int index) {
    final contact = _careCircle[index];
    final initials = contact.name.isNotEmpty ? contact.name.substring(0, 2).toUpperCase() : '??';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: contact.isPrimary ? context.colorScheme.primary : context.colorScheme.outlineVariant.withOpacity(0.5),
          width: contact.isPrimary ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: Text(initials, style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(contact.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(contact.relation, style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(contact.contactInfo, style: TextStyle(color: context.colorScheme.onSurfaceVariant, fontSize: 13), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              contact.isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
              color: contact.isPrimary ? Colors.amber : Colors.grey.shade400,
            ),
            onPressed: () => _setPrimary(index),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
            onPressed: () => _removeContact(index),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_isLoading) {
      return Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(_loadingText, style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _completeRegistration,
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.primary,
              foregroundColor: context.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentStep == 0 ? 'NEXT' : 'COMPLETE SETUP',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
