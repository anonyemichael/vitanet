import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Hydration tracker card ("Hydration · 1.2 of 2.0 L").
///
/// Glasses are stored per day in shared preferences.
class WellnessInsightCard extends StatefulWidget {
  const WellnessInsightCard({super.key});

  @override
  State<WellnessInsightCard> createState() => _WellnessInsightCardState();
}

class _WellnessInsightCardState extends State<WellnessInsightCard> {
  static const _glassMl = 250;
  static const _goalMl = 2000;
  int _glasses = 0;

  String get _key {
    final d = DateTime.now();
    return 'hydration_${d.year}_${d.month}_${d.day}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _glasses = prefs.getInt(_key) ?? 0);
    } catch (_) {}
  }

  Future<void> _addGlass() async {
    setState(() => _glasses += 1);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, _glasses);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final ml = _glasses * _glassMl;
    final pct = ml / _goalMl;
    final left = ((_goalMl - ml) / _glassMl).ceil();
    final tip = left <= 0
        ? 'Daily goal reached. Nice work.'
        : (left == 1
            ? 'One more glass to reach your goal.'
            : '$left more glasses to reach your daily goal.');
    final accent = p.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return VnCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VnIconTile(
            icon: Icons.water_drop_outlined,
            bg: Color(0xFFE0F2FE),
            fg: Color(0xFF0369A1),
            size: 44,
            radius: 14,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hydration · ${(ml / 1000).toStringAsFixed(1)} of ${(_goalMl / 1000).toStringAsFixed(1)} L',
                  style: VnText.body(15, weight: FontWeight.w700, color: p.ink),
                ),
                const SizedBox(height: 8),
                VnProgressBar(
                  value: pct,
                  color: accent,
                  track: p.isDark ? const Color(0xFF0C2A3A) : const Color(0xFFE0F2FE),
                ),
                const SizedBox(height: 8),
                Text(tip, style: VnText.body(13, color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Log a glass of water',
            child: Semantics(
              button: true,
              label: 'Log a glass of water',
              excludeSemantics: true,
              child: Material(
                color: p.isDark ? const Color(0xFF0C2A3A) : const Color(0xFFF0F9FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: p.isDark ? const Color(0xFF155E75) : const Color(0xFFBAE6FD)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _addGlass,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.add_rounded, color: p.tintFg(const Color(0xFF0369A1))),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two quick-link cards: Care nearby and First aid.
class HomeQuickLinks extends StatelessWidget {
  const HomeQuickLinks({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required Color bg,
      required Color fg,
      required String title,
      required String sub,
      required VoidCallback onTap,
    }) {
      final p = VnPalette.of(context);
      return VnCard(
        onTap: onTap,
        semanticLabel: '$title. $sub',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VnIconTile(icon: icon, bg: bg, fg: fg, size: 40),
            const SizedBox(height: 10),
            Text(title, style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 10),
            Text(sub, style: VnText.body(13, color: p.muted)),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: tile(
            icon: Icons.local_pharmacy_outlined,
            bg: const Color(0xFFFEE2E2),
            fg: const Color(0xFFB91C1C),
            title: 'Care nearby',
            sub: 'Pharmacies and clinics',
            onTap: () => context.push('/pharmacy'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: tile(
            icon: Icons.warning_amber_rounded,
            bg: const Color(0xFFFFEDD5),
            fg: const Color(0xFFC2410C),
            title: 'First aid',
            sub: 'Step-by-step guides',
            onTap: () => context.push('/first-aid'),
          ),
        ),
      ],
    );
  }
}
