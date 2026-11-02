import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Amber "Finish your medical profile" banner with a completion ring.
class ProfileCompletionBanner extends StatelessWidget {
  final UserProfile? profile;
  const ProfileCompletionBanner({super.key, this.profile});

  /// Share of key profile fields that are filled in (0..1).
  static double completion(UserProfile? p) {
    if (p == null) return 0;
    bool has(String? s) => s != null && s.trim().isNotEmpty;
    final checks = <bool>[
      p.name.trim().isNotEmpty,
      has(p.phone),
      has(p.dob),
      has(p.sex),
      has(p.bloodType),
      p.height != null,
      p.weight != null,
      p.medications.isNotEmpty,
      p.allergies.isNotEmpty || p.preExistingConditions.isNotEmpty,
      p.emergencyContacts.isNotEmpty,
    ];
    return checks.where((c) => c).length / checks.length;
  }

  static String _hint(UserProfile? p) {
    if (p == null) return 'Add your details so VitaNet can tailor advice';
    bool has(String? s) => s != null && s.trim().isNotEmpty;
    if (p.medications.isEmpty) return 'Add medications so we can check interactions';
    if (!has(p.bloodType)) return 'Add your blood type for emergencies';
    if (p.height == null || p.weight == null) return 'Add height and weight for dosing advice';
    if (p.emergencyContacts.isEmpty) return 'Add a care circle contact';
    return 'A few details left to fill in';
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final pct = completion(profile);
    final bg = p.isDark ? const Color(0xFF2A2010) : const Color(0xFFFFFBEB);
    final border = p.isDark ? const Color(0xFF5C4515) : const Color(0xFFFDE68A);
    final strong = p.isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
    final soft = p.isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/edit-profile', extra: 'medical'),
        child: Semantics(
          button: true,
          label: 'Finish your medical profile, ${(pct * 100).round()} percent complete',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CustomPaint(
                    painter: _RingPainter(
                      pct,
                      const Color(0xFFD97706),
                      p.isDark ? const Color(0xFF5C4515) : const Color(0xFFFDE68A),
                    ),
                    child: Center(
                      child: Text('${(pct * 100).round()}%',
                          style: VnText.body(11, weight: FontWeight.w800, color: strong)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Finish your medical profile',
                          style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                      const SizedBox(height: 2),
                      Text(_hint(profile), style: VnText.body(13, color: soft)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: strong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  _RingPainter(this.value, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const stroke = 5.0;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
