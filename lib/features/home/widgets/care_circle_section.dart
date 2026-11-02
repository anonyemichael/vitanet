import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/screens/add_contact_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Avatar colours cycled across care circle members.
const careCircleAvatarColors = <(Color, Color)>[
  (Color(0xFFEDE9FE), Color(0xFF5B21B6)),
  (Color(0xFFFCE7F3), Color(0xFF9D174D)),
  (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  (Color(0xFFD1FAE5), Color(0xFF065F46)),
  (Color(0xFFFEF3C7), Color(0xFF92400E)),
];

class CareCircleSection extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;
  const CareCircleSection({super.key, this.padding});

  void _openAddContact(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (context) => const AddContactScreen()),
    );
  }

  String _names(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    if (names.length == 3) return '${names[0]}, ${names[1]} and ${names[2]}';
    return '${names[0]}, ${names[1]} and ${names.length - 2} more';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final contacts = ref.watch(userProfileProvider)?.emergencyContacts ?? const [];
    final firstNames = contacts.map((c) => c.name.trim().split(RegExp(r'\s+')).first).toList();
    final shown = contacts.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VnSectionHeader(
          title: 'Care circle',
          action: 'Manage',
          onAction: () => _openAddContact(context),
        ),
        const SizedBox(height: 12),
        VnCard(
          child: Row(
            children: [
              if (shown.isEmpty)
                VnIconTile(
                  icon: Icons.group_add_outlined,
                  bg: const Color(0xFFDBEAFE),
                  fg: const Color(0xFF1E40AF),
                  size: 44,
                  radius: 22,
                )
              else
                SizedBox(
                  width: 44.0 + (shown.length - 1) * 32,
                  height: 44,
                  child: Stack(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Positioned(
                          left: i * 32.0,
                          child: VnAvatar(
                            name: shown[i].name,
                            size: 44,
                            fontSize: 14,
                            bg: careCircleAvatarColors[i % careCircleAvatarColors.length].$1,
                            fg: careCircleAvatarColors[i % careCircleAvatarColors.length].$2,
                            borderWidth: 3,
                            borderColor: p.surface,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contacts.isEmpty
                          ? 'No one is notified yet'
                          : '${contacts.length} ${contacts.length == 1 ? "person" : "people"} notified on urgent results',
                      style: VnText.body(14, weight: FontWeight.w700, color: p.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contacts.isEmpty
                          ? 'Add family or caregivers to alert if a check is urgent'
                          : _names(firstNames),
                      style: VnText.body(13, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              VnIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Add contact',
                size: 44,
                radius: 12,
                background: p.brand,
                foreground: p.onBrand,
                onPressed: () => _openAddContact(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
