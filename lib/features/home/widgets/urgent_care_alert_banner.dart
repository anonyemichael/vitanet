import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/core/constants/app_colors.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/home/screens/add_contact_screen.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Session flag so the urgent dialog auto-opens only once per critical episode.
final _urgentDismissedProvider = StateProvider<bool>((ref) => false);

/// A critical reading derived from live vitals, or null when all is well.
class UrgentReading {
  final String title;
  final String body;
  const UrgentReading(this.title, this.body);

  static UrgentReading? from(Map<String, double> v) {
    final spo2 = v['blood_oxygen'];
    final hr = v['heart_rate'];
    final rr = v['respiratory_rate'];
    final temp = v['temperature'];
    if (spo2 != null && spo2 < 92) {
      return UrgentReading(
        'Your oxygen level is low',
        'Blood oxygen is reading ${spo2.round()}%. Below 92% needs medical attention now, especially with shortness of breath.',
      );
    }
    if (hr != null && (hr >= 130 || hr < 40)) {
      return UrgentReading(
        hr >= 130 ? 'Your heart rate is very high' : 'Your heart rate is very low',
        'Heart rate is reading ${hr.round()} bpm while resting. If you feel faint, breathless or have chest pain, get help now.',
      );
    }
    if (rr != null && rr >= 25) {
      return UrgentReading(
        'You are breathing very fast',
        'Respiratory rate is ${rr.round()} breaths a minute. Rapid breathing at rest needs prompt medical attention.',
      );
    }
    if (temp != null && temp >= 39.5) {
      return UrgentReading(
        'You have a high fever',
        'Body temperature is ${temp.toStringAsFixed(1)} °C. A fever this high with confusion, stiff neck or rash needs urgent care.',
      );
    }
    return null;
  }
}

/// Watches live vitals; when a reading turns critical it opens the urgent
/// alert dialog and keeps a compact red banner on the home screen.
class UrgentCareAlertBanner extends ConsumerStatefulWidget {
  const UrgentCareAlertBanner({super.key});

  @override
  ConsumerState<UrgentCareAlertBanner> createState() =>
      _UrgentCareAlertBannerState();
}

class _UrgentCareAlertBannerState extends ConsumerState<UrgentCareAlertBanner> {
  bool _dialogOpen = false;

  Future<void> _open(UrgentReading reading) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await showUrgentCareAlertDialog(context, reading: reading);
    _dialogOpen = false;
    if (mounted) ref.read(_urgentDismissedProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, double>>(liveVitalsProvider, (prev, next) {
      final now = UrgentReading.from(next);
      final before = prev == null ? null : UrgentReading.from(prev);
      if (now == null) {
        ref.read(_urgentDismissedProvider.notifier).state = false;
      } else if (before == null && !ref.read(_urgentDismissedProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _open(now);
        });
      }
    });

    final reading = UrgentReading.from(ref.watch(liveVitalsProvider));
    if (reading == null) return const SizedBox.shrink();

    final p = VnPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Material(
        color: p.dangerTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.danger.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(reading),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: p.danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(reading.title,
                      style: VnText.body(14, weight: FontWeight.w700, color: p.danger)),
                ),
                Text('What to do',
                    style: VnText.body(13, weight: FontWeight.w700, color: p.danger)),
                Icon(Icons.chevron_right_rounded, color: p.danger),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The urgent alert dialog (UrgentAlert spec).
Future<void> showUrgentCareAlertDialog(
  BuildContext context, {
  required UrgentReading reading,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: const Color(0x990F172A),
    builder: (_) => _UrgentAlertDialog(reading: reading),
  );
}

class _UrgentAlertDialog extends ConsumerWidget {
  final UrgentReading reading;
  const _UrgentAlertDialog({required this.reading});

  Future<void> _call(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = VnPalette.of(context);
    final vitals = ref.watch(liveVitalsProvider);
    final contacts = ref.watch(userProfileProvider)?.emergencyContacts ?? const <EmergencyContact>[];
    final primary = contacts.where((c) => c.phone.trim().isNotEmpty).firstOrNull;

    Widget stat(String label, String value, Color bg, Color labelColor, Color valueColor) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.isDark ? valueColor.withValues(alpha: 0.16) : bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: VnText.body(11,
                        weight: FontWeight.w600, color: p.isDark ? p.muted : labelColor)),
                const SizedBox(height: 2),
                Text(value,
                    style: VnText.heading(20,
                        color: p.isDark ? p.tintFg(valueColor) : valueColor)),
              ],
            ),
          ),
        );

    Widget soft(String label, IconData icon, VoidCallback onTap) => Expanded(
          child: VnOutlineButton(
            label: label,
            icon: icon,
            height: 50,
            radius: 14,
            fontSize: 14,
            background: p.surfaceAlt,
            borderColor: Colors.transparent,
            onPressed: onTap,
          ),
        );

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: reading.title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.danger,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(reading.title,
                        style: VnText.heading(22, color: Colors.white, height: 1.25)),
                    const SizedBox(height: 12),
                    Text(reading.body,
                        style: VnText.body(14,
                            color: const Color(0xFFFEE2E2), height: 1.5)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        stat(
                          'SpO2',
                          vitals['blood_oxygen'] == null
                              ? '--'
                              : '${vitals['blood_oxygen']!.round()}%',
                          const Color(0xFFFEF2F2),
                          const Color(0xFF991B1B),
                          const Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 8),
                        stat(
                          'Heart',
                          vitals['heart_rate']?.round().toString() ?? '--',
                          const Color(0xFFFFF7ED),
                          const Color(0xFF9A3412),
                          const Color(0xFFC2410C),
                        ),
                        const SizedBox(width: 8),
                        stat(
                          'Resp.',
                          vitals['respiratory_rate']?.round().toString() ?? '--',
                          AppColors.pageBg,
                          AppColors.inkSoft,
                          p.isDark ? p.ink : AppColors.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    VnButton(
                      label: 'Call emergency services (112)',
                      icon: Icons.call_rounded,
                      background: AppColors.danger,
                      foreground: Colors.white,
                      onPressed: () => _call('112'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        soft('Alert circle', Icons.group_outlined, () {
                          if (primary != null) {
                            _call(primary.phone);
                          } else {
                            final nav = Navigator.of(context, rootNavigator: true);
                            nav.pop();
                            nav.push(
                              MaterialPageRoute(builder: (_) => const AddContactScreen()),
                            );
                          }
                        }),
                        const SizedBox(width: 10),
                        soft('Nearest ER', Icons.location_on_outlined, () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.push('/pharmacy');
                        }),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: p.inkSoft,
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("I'm okay, it was a sensor error",
                            style: VnText.body(14, weight: FontWeight.w600, color: p.inkSoft)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
