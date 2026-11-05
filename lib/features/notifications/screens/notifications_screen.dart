import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/data/models/triage_result.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// When the user last pressed "Mark all read" (null = never this session).
final notificationsLastReadProvider = StateProvider<DateTime?>((ref) => null);

/// Whether there are unread notifications (drives the home bell badge).
///
/// Derived from real events only (saved symptom-check results from the last
/// 24 hours that arrived after the user last marked everything read). A
/// brand-new user with no history therefore always reports `false`.
final notificationsUnreadProvider = Provider<bool>((ref) {
  final history = ref.watch(triageHistoryProvider);
  final lastRead = ref.watch(notificationsLastReadProvider);
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));
  return history.any(
    (t) =>
        t.timestamp.isAfter(cutoff) &&
        (lastRead == null || t.timestamp.isAfter(lastRead)),
  );
});

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
  final DateTime timestamp;
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
    required this.timestamp,
    this.unread = false,
    this.action,
    this.onAction,
  });
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0;

  static String _formatTime(DateTime t, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (diff < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[t.weekday - 1];
    }
    return '${t.day}/${t.month}/${t.year}';
  }

  /// Builds notification items from real, locally stored events only.
  List<_Notif> _buildItems(List<TriageResult> history, DateTime? lastRead) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    final sorted = [...history]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return [
      for (final t in sorted.take(30))
        _fromTriage(
          t,
          time: _formatTime(t.timestamp, now),
          unread:
              t.timestamp.isAfter(cutoff) &&
              (lastRead == null || t.timestamp.isAfter(lastRead)),
        ),
    ];
  }

  _Notif _fromTriage(
    TriageResult t, {
    required String time,
    required bool unread,
  }) {
    final (
      String advice,
      Color bg,
      Color fg,
      IconData icon,
      _NotifKind kind,
    ) = switch (t.level) {
      TriageLevel.emergency => (
        'Advised: seek emergency care.',
        const Color(0xFFFFE4E6),
        const Color(0xFFBE123C),
        Icons.warning_amber_rounded,
        _NotifKind.health,
      ),
      TriageLevel.doctor => (
        'Advised: see a doctor.',
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
        Icons.medical_services_outlined,
        _NotifKind.health,
      ),
      TriageLevel.pharmacist => (
        'Advised: see a pharmacist.',
        const Color(0xFFEDE9FE),
        const Color(0xFF6D28D9),
        Icons.local_pharmacy_outlined,
        _NotifKind.other,
      ),
      TriageLevel.selfCare => (
        'Advised: self-care at home.',
        const Color(0xFFD1FAE5),
        const Color(0xFF047857),
        Icons.description_outlined,
        _NotifKind.other,
      ),
    };
    final subject = t.primarySymptom.trim().isNotEmpty
        ? t.primarySymptom.trim()
        : (t.summary.trim().isNotEmpty ? t.summary.trim() : 'Symptom check');
    return _Notif(
      title: 'Check result saved',
      time: time,
      body: '$subject. $advice',
      icon: icon,
      bg: bg,
      fg: fg,
      kind: kind,
      timestamp: t.timestamp,
      unread: unread,
      action: 'View history',
      onAction: (c) => c.push('/history'),
    );
  }

  bool _matches(_Notif n) => switch (_tab) {
    1 => n.kind == _NotifKind.health,
    2 => n.kind == _NotifKind.care,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final unread = ref.watch(notificationsUnreadProvider);
    final history = ref.watch(triageHistoryProvider);
    final lastRead = ref.watch(notificationsLastReadProvider);
    final all = _buildItems(history, lastRead).where(_matches).toList();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final today = all
        .where((n) => !n.timestamp.isBefore(startOfToday))
        .toList();
    final earlier = all
        .where((n) => n.timestamp.isBefore(startOfToday))
        .toList();

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
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
                              ? () =>
                                    ref
                                            .read(
                                              notificationsLastReadProvider
                                                  .notifier,
                                            )
                                            .state =
                                        DateTime.now()
                              : null,
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            child: Text(
                              'Mark all read',
                              style: VnText.body(
                                13,
                                weight: FontWeight.w700,
                                color: unread ? p.brand : p.faint,
                              ),
                            ),
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
                    _NotificationTile(n: n, unread: n.unread),
                    const SizedBox(height: 10),
                  ],
                ],
                if (earlier.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const VnSectionLabel('Earlier', padding: EdgeInsets.zero),
                  const SizedBox(height: 18),
                  for (final n in earlier) ...[
                    _NotificationTile(n: n, unread: n.unread),
                    const SizedBox(height: 10),
                  ],
                ],
                if (today.isEmpty && earlier.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 40,
                          color: p.faint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: VnText.heading(
                            16,
                            weight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Alerts appear here when your vitals, symptom checks or care circle need your attention.',
                          textAlign: TextAlign.center,
                          style: VnText.body(13, color: p.muted),
                        ),
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
                      child: Text(
                        n.title,
                        style: VnText.body(
                          14,
                          weight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(n.time, style: VnText.body(12, color: p.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.body,
                  style: VnText.body(13, color: p.inkSoft, height: 1.45),
                ),
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
                  decoration: BoxDecoration(
                    color: p.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
