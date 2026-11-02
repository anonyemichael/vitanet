import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Whether there are unread notifications (drives the home bell badge).
final notificationsUnreadProvider = StateProvider<bool>((ref) => true);

enum _NotifKind { health, care, other }

class _Notif {
  final String title;
  final String time;
  final String body;
  final IconData icon;
  final Color bg;
  final Color fg;
  final _NotifKind kind;
  final bool unread;
  final String? action;
  final void Function(BuildContext context)? onAction;

  const _Notif({
    required this.title,
    required this.time,
    required this.body,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.kind,
    this.unread = false,
    this.action,
    this.onAction,
  });
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0;

  static final List<_Notif> _today = [
    _Notif(
      title: 'Heart rate spike',
      time: '9:42',
      body:
          'Resting heart rate hit 118 bpm for 6 minutes while you were inactive. Log what you were doing?',
      icon: Icons.monitor_heart_outlined,
      bg: const Color(0xFFFFE4E6),
      fg: const Color(0xFFBE123C),
      kind: _NotifKind.health,
      unread: true,
      action: 'Log activity',
      onAction: (c) => c.push('/health-trends/heart_rate'),
    ),
    _Notif(
      title: 'Medication reminder',
      time: '9:00',
      body: 'Your preventer inhaler is due. Take it now to stay on your plan.',
      icon: Icons.medication_outlined,
      bg: const Color(0xFFEDE9FE),
      fg: const Color(0xFF6D28D9),
      kind: _NotifKind.health,
      unread: true,
      action: 'Log dose',
      onAction: (c) => c.showSnack('Dose logged for today'),
    ),
    _Notif(
      title: 'Care circle updated',
      time: '8:15',
      body:
          'Your contacts will be alerted with your location if a check comes back urgent.',
      icon: Icons.group_outlined,
      bg: const Color(0xFFDBEAFE),
      fg: const Color(0xFF1D4ED8),
      kind: _NotifKind.care,
      unread: true,
    ),
    _Notif(
      title: 'Blood oxygen summary',
      time: '7:02',
      body: 'Overnight SpO2 stayed between 96% and 99%. No dips detected.',
      icon: Icons.water_drop_outlined,
      bg: const Color(0xFFE0E7FF),
      fg: const Color(0xFF4338CA),
      kind: _NotifKind.health,
      action: 'View trend',
      onAction: (c) => c.push('/health-trends/blood_oxygen'),
    ),
  ];

  static const List<_Notif> _earlier = [
    _Notif(
      title: 'Activity goal met',
      time: 'Tue',
      body: 'Third day in a row above your step goal.',
      icon: Icons.check_rounded,
      bg: Color(0xFFD1FAE5),
      fg: Color(0xFF047857),
      kind: _NotifKind.health,
    ),
    _Notif(
      title: 'Check result saved',
      time: 'Mon',
      body: 'Sore throat and mild fever. Advised: see a pharmacist.',
      icon: Icons.description_outlined,
      bg: Color(0xFFFEF3C7),
      fg: Color(0xFFB45309),
      kind: _NotifKind.other,
    ),
    _Notif(
      title: 'New video in First Aid',
      time: 'Sun',
      body: 'Choking in infants: back blows and chest thrusts, 4 min.',
      icon: Icons.play_arrow_outlined,
      bg: Color(0xFFFFEDD5),
      fg: Color(0xFFC2410C),
      kind: _NotifKind.other,
    ),
  ];

  bool _matches(_Notif n) => switch (_tab) {
        1 => n.kind == _NotifKind.health,
        2 => n.kind == _NotifKind.care,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final unread = ref.watch(notificationsUnreadProvider);
    final today = _today.where(_matches).toList();
    final earlier = _earlier.where(_matches).toList();

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                VnTopBar(
                  title: 'Notifications',
                  actions: [
                    Semantics(
                      button: true,
                      child: Material(
                        color: p.brandWash,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: unread
                              ? () => ref.read(notificationsUnreadProvider.notifier).state = false
                              : null,
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            child: Text('Mark all read',
                                style: VnText.body(13,
                                    weight: FontWeight.w700,
                                    color: unread ? p.brand : p.faint)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                VnSegmented(
                  options: const ['All', 'Health alerts', 'Care circle'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                if (today.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const VnSectionLabel('Today', padding: EdgeInsets.zero),
                  const SizedBox(height: 18),
                  for (final n in today) ...[
                    _NotificationTile(n: n, unread: n.unread && unread),
                    const SizedBox(height: 10),
                  ],
                ],
                if (earlier.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const VnSectionLabel('Earlier this week', padding: EdgeInsets.zero),
                  const SizedBox(height: 18),
                  for (final n in earlier) ...[
                    _NotificationTile(n: n, unread: false),
                    const SizedBox(height: 10),
                  ],
                ],
                if (today.isEmpty && earlier.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 40, color: p.faint),
                        const SizedBox(height: 12),
                        Text('Nothing here yet',
                            style: VnText.heading(16, weight: FontWeight.w700, color: p.ink)),
                        const SizedBox(height: 4),
                        Text('Updates from your care circle will appear here.',
                            textAlign: TextAlign.center,
                            style: VnText.body(13, color: p.muted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _Notif n;
  final bool unread;
  const _NotificationTile({required this.n, required this.unread});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread ? p.brandWash : p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: unread ? p.brandBorder : p.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VnIconTile(icon: n.icon, bg: n.bg, fg: n.fg, size: 42, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: VnText.body(14, weight: FontWeight.w700, color: p.ink)),
                    ),
                    const SizedBox(width: 8),
                    Text(n.time, style: VnText.body(12, color: p.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(n.body, style: VnText.body(13, color: p.inkSoft, height: 1.45)),
                if (n.action != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: VnLink(
                      label: n.action!,
                      fontSize: 13,
                      weight: FontWeight.w700,
                      onTap: () => n.onAction?.call(context),
                    ),
                  ),
              ],
            ),
          ),
          if (unread)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: Semantics(
                label: 'Unread',
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: p.brand, shape: BoxShape.circle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
