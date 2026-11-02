import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// When readings were last pulled successfully from a real source (device /
/// health platform, or the signed-in user's backend record). `null` means no
/// source has delivered data this session.
final vitalsLastSyncProvider = StateProvider<DateTime?>((ref) => null);

/// Readings older than this are not presented as "live".
const _freshWindow = Duration(minutes: 2);

/// "Today's vitals" 2x2 grid driven by [liveVitalsProvider].
class HealthOverviewSection extends ConsumerStatefulWidget {
  const HealthOverviewSection({super.key});

  @override
  ConsumerState<HealthOverviewSection> createState() =>
      _HealthOverviewSectionState();
}

class _HealthOverviewSectionState extends ConsumerState<HealthOverviewSection> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLiveUpdates();
  }

  void _startLiveUpdates() {
    _fetchAndUpdateVitals();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchAndUpdateVitals();
      // Re-evaluate freshness so a stale source stops showing as "Live".
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchAndUpdateVitals() async {
    if (!mounted) return;
    try {
      if (!kIsWeb) {
        final biometrics = await ref
            .read(healthServiceProvider)
            .fetchBiometrics();
        if (biometrics.isNotEmpty && mounted) {
          var any = false;
          biometrics.forEach((key, value) {
            final doubleVal = double.tryParse(value.toString());
            if (doubleVal != null) {
              ref.read(liveVitalsProvider.notifier).setVital(key, doubleVal);
              any = true;
            }
          });
          if (any) {
            ref.read(vitalsLastSyncProvider.notifier).state = DateTime.now();
            return;
          }
        }
      }
      // Only a signed-in (non-guest) account has its own backend vitals
      // record; never fall back to a shared demo user.
      final user = ref.read(authProvider).user;
      if (user == null || user.isAnonymous) return;
      final backendVitals = await ref
          .read(apiServiceProvider)
          .getLatestVitals(user.uid);
      if (backendVitals.isNotEmpty && mounted) {
        backendVitals.forEach((key, val) {
          ref.read(liveVitalsProvider.notifier).setVital(key, val);
        });
        ref.read(vitalsLastSyncProvider.notifier).state = DateTime.now();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final vitals = ref.watch(liveVitalsProvider);
    final lastSync = ref.watch(vitalsLastSyncProvider);
    final hasReadings = vitals.isNotEmpty;
    final isFresh =
        hasReadings &&
        lastSync != null &&
        DateTime.now().difference(lastSync) < _freshWindow;

    String status(String id, double v) {
      switch (id) {
        case 'heart_rate':
          return v < 50 ? 'Low' : (v > 100 ? 'High' : 'Normal');
        case 'blood_oxygen':
          return v < 92 ? 'Low' : (v < 95 ? 'Watch' : 'Normal');
        case 'temperature':
          return v >= 38 ? 'Fever' : (v < 35.5 ? 'Low' : 'Normal');
        case 'respiratory_rate':
          return v > 20 ? 'High' : (v < 10 ? 'Low' : 'Normal');
      }
      return 'Normal';
    }

    final cards = <_VitalSpec>[
      _VitalSpec(
        id: 'heart_rate',
        label: 'Heart rate',
        unit: 'bpm',
        icon: Icons.favorite_border_rounded,
        color: const Color(0xFFE11D48),
        bg: const Color(0xFFFFE4E6),
        fg: const Color(0xFFBE123C),
        format: (v) => v.round().toString(),
      ),
      _VitalSpec(
        id: 'blood_oxygen',
        label: 'Blood oxygen',
        unit: '%',
        icon: Icons.water_drop_outlined,
        color: const Color(0xFF0284C7),
        bg: const Color(0xFFE0F2FE),
        fg: const Color(0xFF0369A1),
        format: (v) => v.toStringAsFixed(0),
      ),
      _VitalSpec(
        id: 'temperature',
        label: 'Body temp',
        unit: '°C',
        icon: Icons.thermostat_rounded,
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFEF3C7),
        fg: const Color(0xFFB45309),
        format: (v) => v.toStringAsFixed(1),
      ),
      _VitalSpec(
        id: 'respiratory_rate',
        label: 'Respiratory rate',
        unit: '/min',
        icon: Icons.air_rounded,
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFEDE9FE),
        fg: const Color(0xFF6D28D9),
        format: (v) => v.round().toString(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VnSectionHeader(
          title: "Today's vitals",
          trailing: isFresh
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live · Connected device',
                      style: VnText.body(
                        12,
                        weight: FontWeight.w600,
                        color: p.isDark
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasReadings ? 'Not live' : 'No device connected',
                      style: VnText.body(
                        12,
                        weight: FontWeight.w600,
                        color: p.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    VnLink(
                      label: hasReadings ? 'Sync' : 'Connect',
                      fontSize: 13,
                      weight: FontWeight.w700,
                      onTap: () =>
                          context.push('/device-connection/heart_rate'),
                    ),
                  ],
                ),
        ),
        if (!hasReadings) ...[
          const SizedBox(height: 4),
          Text(
            'Connect a watch to see live vitals',
            style: VnText.body(13, color: p.muted),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 720 ? 4 : 2;
            const gap = 12.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final s in cards)
                  SizedBox(
                    width: w,
                    child: _VitalCard(
                      spec: s,
                      value: vitals[s.id],
                      status: vitals[s.id] == null
                          ? null
                          : status(s.id, vitals[s.id]!),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _VitalSpec {
  final String id;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final Color bg;
  final Color fg;
  final String Function(double) format;

  const _VitalSpec({
    required this.id,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.bg,
    required this.fg,
    required this.format,
  });
}

class _VitalCard extends StatelessWidget {
  final _VitalSpec spec;
  final double? value;
  final String? status;

  const _VitalCard({
    required this.spec,
    required this.value,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final connected = value != null;
    final normal = status == 'Normal';
    final statusColor = !connected
        ? p.brand
        : normal
        ? (p.isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
        : (p.isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309));

    return VnCard(
      semanticLabel: connected
          ? '${spec.label} ${spec.format(value!)} ${spec.unit}, $status'
          : '${spec.label}, no device connected. Tap to connect',
      onTap: () => connected
          ? context.push('/health-trends/${spec.id}')
          : context.push('/device-connection/${spec.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VnIconTile(
                icon: spec.icon,
                bg: spec.bg,
                fg: spec.fg,
                size: 34,
                radius: 10,
                iconSize: 18,
              ),
              const Spacer(),
              Text(
                connected ? status! : 'Connect',
                style: VnText.body(
                  11,
                  weight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            spec.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VnText.body(13, weight: FontWeight.w500, color: p.muted),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  connected ? spec.format(value!) : '—',
                  maxLines: 1,
                  style: VnText.heading(26, color: p.ink),
                ),
              ),
              const SizedBox(width: 4),
              Text(spec.unit, style: VnText.body(13, color: p.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
