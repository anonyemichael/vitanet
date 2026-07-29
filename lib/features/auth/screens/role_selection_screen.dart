import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/shared/widgets/animated_logo.dart';
import 'package:vitanet/shared/widgets/gradient_background.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: isWide 
          ? const _WideRoleSelection() 
          : const _NarrowRoleSelection(),
    );
  }
}

class _WideRoleSelection extends StatelessWidget {
  const _WideRoleSelection();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ImageRoleCard(
            title: 'Personal User',
            subtitle: 'Check symptoms and manage your health securely',
            imagePath: 'assets/images/patient_login.jpg',
            icon: Icons.person_rounded,
            onTap: () => context.push('/login/patient'),
          ),
        ),
        Expanded(
          child: _ImageRoleCard(
            title: 'Hospital Personnel',
            subtitle: 'Access the admin dashboard and review cases',
            imagePath: 'assets/images/staff_login.jpg',
            icon: Icons.medical_services_rounded,
            onTap: () => context.push('/login/hospital_personnel'),
          ),
        ),
      ],
    );
  }
}

class _NarrowRoleSelection extends StatelessWidget {
  const _NarrowRoleSelection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _ImageRoleCard(
            title: 'Personal User',
            subtitle: 'Check symptoms and manage your health securely',
            imagePath: 'assets/images/patient_login.jpg',
            icon: Icons.person_rounded,
            onTap: () => context.push('/login/patient'),
          ),
        ),
        Expanded(
          child: _ImageRoleCard(
            title: 'Hospital Personnel',
            subtitle: 'Access the admin dashboard and review cases',
            imagePath: 'assets/images/staff_login.jpg',
            icon: Icons.medical_services_rounded,
            onTap: () => context.push('/login/hospital_personnel'),
          ),
        ),
      ],
    );
  }
}

class _ImageRoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final IconData icon;
  final VoidCallback onTap;

  const _ImageRoleCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ImageRoleCard> createState() => _ImageRoleCardState();
}

class _ImageRoleCardState extends State<_ImageRoleCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image with Scale Transition
            ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: context.colorScheme.primary),
              ),
            ),
            
            // Overlay gradient
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: _isHovered ? 0.3 : 0.6),
                    Colors.black.withValues(alpha: _isHovered ? 0.7 : 0.9),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isHovered 
                          ? context.colorScheme.primary 
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isHovered ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    widget.title,
                    style: context.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isHovered ? 1.0 : 0.7,
                    child: Text(
                      widget.subtitle,
                      style: context.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
