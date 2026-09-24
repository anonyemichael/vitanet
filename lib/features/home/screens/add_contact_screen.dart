import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedRole = 'Family';
  bool _isPrimary = false;

  late AnimationController _animController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  final List<Map<String, dynamic>> _roles = [
    {'name': 'Family', 'icon': Icons.favorite_rounded, 'color': Colors.pink},
    {'name': 'Friend', 'icon': Icons.handshake_rounded, 'color': Colors.orange},
    {'name': 'Doctor', 'icon': Icons.medical_services_rounded, 'color': Colors.blue},
    {'name': 'Neighbor', 'icon': Icons.home_rounded, 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimations = List.generate(4, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(index * 0.15, 1.0, curve: Curves.easeOut),
        ),
      );
    });

    _slideAnimations = List.generate(4, (index) {
      return Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(index * 0.15, 1.0, curve: Curves.easeOutCubic),
        ),
      );
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _saveContact() {
    if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
      final currentProfile = ref.read(userProfileProvider);
      if (currentProfile != null) {
        final newContact = EmergencyContact(
          name: _nameController.text,
          phone: _phoneController.text,
          relation: _selectedRole,
        );

        final updatedContacts = List<EmergencyContact>.from(currentProfile.emergencyContacts);
        
        if (_isPrimary) {
          updatedContacts.insert(0, newContact);
        } else {
          updatedContacts.add(newContact);
        }

        final updatedProfile = currentProfile.copyWith(emergencyContacts: updatedContacts);
        ref.read(userProfileProvider.notifier).updateProfile(updatedProfile);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(top: 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              title: Text(
                'Add Member',
                style: TextStyle(
                  color: context.isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Identity Card
                  FadeTransition(
                    opacity: _fadeAnimations[0],
                    child: SlideTransition(
                      position: _slideAnimations[0],
                      child: _buildFormCard(
                        title: 'Identity',
                        children: [
                          Text('Full Name', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., John Doe',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Contact Card
                  FadeTransition(
                    opacity: _fadeAnimations[1],
                    child: SlideTransition(
                      position: _slideAnimations[1],
                      child: _buildFormCard(
                        title: 'Contact Details',
                        children: [
                          Text('Phone Number', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '(555) 123-4567',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Role Selection
                  FadeTransition(
                    opacity: _fadeAnimations[2],
                    child: SlideTransition(
                      position: _slideAnimations[2],
                      child: _buildFormCard(
                        title: 'Role & Permissions',
                        children: [
                          Text('Relationship', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _roles.map((role) {
                              final isSelected = _selectedRole == role['name'];
                              return GestureDetector(
                                onTap: () => setState(() => _selectedRole = role['name'] as String),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? (role['color'] as Color).withValues(alpha: 0.15)
                                        : (context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected 
                                          ? (role['color'] as Color).withValues(alpha: 0.5)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        role['icon'] as IconData, 
                                        size: 16, 
                                        color: isSelected ? (role['color'] as Color) : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        role['name'] as String,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected 
                                              ? (role['color'] as Color)
                                              : (context.isDark ? Colors.white70 : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SwitchListTile(
                            title: Text('Primary Emergency Contact', style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Text('They will be alerted first during an emergency.', style: Theme.of(context).textTheme.bodySmall),
                            value: _isPrimary,
                            onChanged: (val) => setState(() => _isPrimary = val),
                            contentPadding: EdgeInsets.zero,
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // Submit Button
                  FadeTransition(
                    opacity: _fadeAnimations[3],
                    child: SlideTransition(
                      position: _slideAnimations[3],
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          onPressed: _saveContact,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Add Member',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // padding for scroll
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}
