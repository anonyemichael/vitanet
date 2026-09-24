import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/widgets/ai_health_alerts_section.dart';

class UrgentCareAlertBanner extends ConsumerStatefulWidget {
  const UrgentCareAlertBanner({super.key});

  @override
  ConsumerState<UrgentCareAlertBanner> createState() => _UrgentCareAlertBannerState();
}

class _UrgentCareAlertBannerState extends ConsumerState<UrgentCareAlertBanner> {
  bool _showAlert = true;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showAlert) return const SizedBox.shrink();

    final profile = ref.watch(userProfileProvider);
    final contacts = profile?.emergencyContacts ?? [];
    
    // Get the primary contact for the urgent alert if available
    final primaryContact = contacts.isNotEmpty ? contacts.first : null;
    final primaryName = (primaryContact?.name ?? 'Mary').split(' ').first;
    final primaryPhone = primaryContact?.phone;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          Dismissible(
            key: const ValueKey('care_circle_alert'),
            direction: DismissDirection.horizontal,
            onDismissed: (direction) {
              setState(() {
                _showAlert = false;
              });
            },
            background: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: AppSpacing.xl),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.xl),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            ),
            child: AlertTile(
              icon: Icons.warning_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Urgent Update: $primaryName',
              description: '$primaryName\'s blood pressure is unusually high. Consider calling to check on them.',
              actionText: 'Call $primaryName Now',
              actionColor: const Color(0xFFEF4444),
              showDot: true,
              dotColor: const Color(0xFFEF4444),
              timestamp: '10m ago',
              onActionTap: () {
                if (primaryPhone != null) {
                  _launchUrl('tel:$primaryPhone');
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
