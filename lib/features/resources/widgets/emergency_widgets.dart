import 'package:flutter/material.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/features/first_aid/screens/first_aid_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// White "Call 112 first" card used in the red emergency header.
class EmergencyCallCard extends StatelessWidget {
  final String emergencyNumber;
  const EmergencyCallCard({super.key, this.emergencyNumber = '112'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Call $emergencyNumber first, then follow a guide below',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => LaunchHelpers.dialOrSnack(context, emergencyNumber),
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Color(0xFFB91C1C), shape: BoxShape.circle),
                    child: const Icon(Icons.phone_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Call $emergencyNumber first',
                            style: VnText.body(16, weight: FontWeight.w800, color: const Color(0xFFB91C1C))),
                        Text('Then follow a guide below',
                            style: VnText.body(12, color: const Color(0xFF991B1B))),
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
}

/// Deep red header: back + title, call card, protocol search and live location.
class EmergencyHeader extends StatelessWidget {
  final String emergencyNumber;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onBack;
  final String locationText;
  final bool isLocating;
  final VoidCallback onCopyLocation;

  const EmergencyHeader({
    super.key,
    required this.emergencyNumber,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onBack,
    required this.locationText,
    required this.isLocating,
    required this.onCopyLocation,
  });

  @override
  Widget build(BuildContext context) {
    const onRed = Color(0xFFFECACA);
    return Container(
      color: const Color(0xFF7F1D1D),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                VnIconButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Back',
                  iconSize: 26,
                  background: const Color(0x1FFFFFFF),
                  foreground: Colors.white,
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Emergency protocols', style: VnText.heading(20, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EmergencyCallCard(emergencyNumber: emergencyNumber),
          const SizedBox(height: 16),
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 14, right: 2),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 20, color: onRed),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    cursorColor: Colors.white,
                    style: VnText.body(15, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search protocols',
                      hintStyle: VnText.body(15, color: onRed),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : VnIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Clear search',
                          iconSize: 18,
                          foreground: onRed,
                          onPressed: onClearSearch,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Your location: $locationText. Tap to copy for the dispatcher.',
            excludeSemantics: true,
            child: InkWell(
              onTap: onCopyLocation,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    if (isLocating)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: onRed),
                      )
                    else
                      const Icon(Icons.my_location_rounded, size: 16, color: onRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VnText.body(13, weight: FontWeight.w500, color: onRed),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Copy', style: VnText.body(13, weight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width row for a life-threatening protocol.
class CriticalProtocolTile extends StatelessWidget {
  final FirstAidTip tip;
  final VoidCallback onTap;
  const CriticalProtocolTile({super.key, required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final sub = '${tip.cue ?? tip.summary} · ${tip.steps.length} steps';
    return VnCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(14),
      semanticLabel: '${tip.title}. $sub',
      child: Row(
        children: [
          VnIconTile(
            icon: tip.icon,
            bg: const Color(0xFFFEE2E2),
            fg: const Color(0xFFB91C1C),
            size: 46,
            radius: 14,
            iconSize: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.title, style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: VnText.body(13, color: p.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.faint),
        ],
      ),
    );
  }
}

/// Grid tile for an urgent-but-manageable guide.
class MinorProtocolTile extends StatelessWidget {
  final FirstAidTip tip;
  final VoidCallback onTap;
  const MinorProtocolTile({super.key, required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final sub = tip.cue ?? tip.summary;
    return VnCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(14),
      semanticLabel: '${tip.title}. $sub',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 104),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VnIconTile(
              icon: tip.icon,
              bg: const Color(0xFFFFEDD5),
              fg: const Color(0xFFC2410C),
              size: 40,
              radius: 12,
            ),
            const SizedBox(height: 10),
            Text(tip.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 4),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: VnText.body(12, color: p.muted)),
          ],
        ),
      ),
    );
  }
}
