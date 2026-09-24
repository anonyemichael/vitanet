import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/screens/add_contact_screen.dart';
import 'package:vitanet/features/home/widgets/ai_health_alerts_section.dart';

class CareCircleSection extends ConsumerStatefulWidget {
  const CareCircleSection({super.key});

  @override
  ConsumerState<CareCircleSection> createState() => _CareCircleSectionState();
}

class _CareCircleSectionState extends ConsumerState<CareCircleSection> {
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _navigateToAddContact() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddContactScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final contacts = profile?.emergencyContacts ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Care Circle',
                style: TextStyle(
                  color: context.isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Manage',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        
        SizedBox(
          height: 90,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            children: [
              if (contacts.isEmpty) ...[
                PulsatingAvatar(
                  name: 'Dr. Sarah',
                  icon: Icons.local_hospital_rounded,
                  color: const Color(0xFF6366F1),
                  isOnline: true,
                  onTap: () => _launchUrl('tel:1234567890'),
                ),
                const SizedBox(width: AppSpacing.lg),
                PulsatingAvatar(
                  name: 'Mary S.',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF10B981),
                  isOnline: true,
                  onTap: () => _launchUrl('tel:0987654321'),
                ),
              ] else ...[
                for (var contact in contacts) ...[
                  PulsatingAvatar(
                    name: contact.name.split(' ').first,
                    icon: Icons.person_rounded,
                    color: const Color(0xFF10B981),
                    isOnline: true, // Mock online status
                    onTap: () {
                      if (contact.phone.isNotEmpty) {
                        _launchUrl('tel:${contact.phone}');
                      }
                    },
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
              ],
              PulsatingAvatar(
                name: 'Add Member',
                icon: Icons.add_rounded,
                color: Colors.grey,
                isOnline: false,
                isDashed: true,
                onTap: _navigateToAddContact,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class PulsatingAvatar extends StatefulWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isOnline;
  final bool isDashed;
  final VoidCallback? onTap;

  const PulsatingAvatar({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    this.isOnline = false,
    this.isDashed = false,
    this.onTap,
  });

  @override
  State<PulsatingAvatar> createState() => _PulsatingAvatarState();
}

class _PulsatingAvatarState extends State<PulsatingAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isOnline) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    
    return RepaintBoundary(
      child: GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isOnline)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(alpha: 1.0 - (_pulseAnimation.value - 1.0) * 5),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDashed 
                    ? Colors.transparent 
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : widget.color.withValues(alpha: 0.1)),
                border: widget.isDashed
                    ? Border.all(color: isDark ? Colors.white24 : Colors.black26, width: 2)
                    : null,
              ),
              child: Icon(
                widget.icon,
                color: widget.isDashed 
                    ? (isDark ? Colors.white54 : Colors.black54)
                    : widget.color,
                size: 28,
              ),
            ),
            if (widget.isOnline)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Online green
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.name,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
    ),
  );
}
}
