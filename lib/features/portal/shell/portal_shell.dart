import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/board/board_screen.dart';
import 'package:vitanet/features/portal/data/portal_live.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';
import 'package:vitanet/features/portal/data/portal_providers.dart';
import 'package:vitanet/features/portal/hospital/hospital_screen.dart';
import 'package:vitanet/features/portal/me/me_screen.dart';
import 'package:vitanet/features/portal/patients/patients_screen.dart';
import 'package:vitanet/features/portal/shell/portal_nav.dart';
import 'package:vitanet/features/portal/ui/clinical_ui.dart';

/// The portal for approved staff: Board, Patients, Hospital, Me. Bottom tabs
/// on phones; a navy rail with two-pane screens on desk.
class PortalShell extends ConsumerStatefulWidget {
  final StaffMe me;
  const PortalShell({super.key, required this.me});

  @override
  ConsumerState<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends ConsumerState<PortalShell> {
  int _tab = 0;
  Set<String>? _seenReferrals;

  void _open(int tab) => setState(() => _tab = tab);

  /// Speaks newly arrived urgent referrals (if the person turned it on).
  void _onIncoming(AsyncValue<List<Referral>>? prev, AsyncValue<List<Referral>> next) {
    final list = next.valueOrNull;
    if (list == null) return;
    final ids = list.map((r) => r.id).toSet();
    final seen = _seenReferrals;
    _seenReferrals = {...?seen, ...ids};
    if (seen == null || !ref.read(announceNewPatientsProvider)) return;
    final fresh = list.where((r) => !seen.contains(r.id)).toList();
    if (fresh.isEmpty) return;
    final r = fresh.firstWhere((r) => r.triageLevel == 'urgent', orElse: () => fresh.first);
    final mins = r.minutesToArrival();
    ref.read(announcerProvider).say(
          '${r.triageLevel == 'urgent' ? 'Urgent patient' : 'New patient'} incoming. '
          '${r.summary.complaint ?? ''}. ${mins == null || mins <= 0 ? '' : 'Arriving in $mins minutes.'}',
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(portalLiveProvider); // live while the portal is open
    ref.listen(referralsProvider('new'), _onIncoming);
    final p = ClinicalPalette.of(context);
    final incoming = ref.watch(referralsProvider('new')).valueOrNull?.length ?? 0;
    final pages = [
      BoardScreen(onOpenTab: _open),
      const PatientsScreen(),
      const HospitalScreen(),
      MeScreen(onOpenTab: _open),
    ];
    const items = [
      (Icons.view_kanban_outlined, Icons.view_kanban_rounded, 'Board'),
      (Icons.people_outline_rounded, Icons.people_rounded, 'Patients'),
      (Icons.local_hospital_outlined, Icons.local_hospital_rounded, 'Hospital'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
    ];
    final body = IndexedStack(index: _tab, children: pages);

    if (isDesk(context)) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 88,
              color: p.navy,
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Text('V', style: cText(17, weight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < items.length; i++) ...[
                      _RailItem(
                        icon: _tab == i ? items[i].$2 : items[i].$1,
                        label: items[i].$3,
                        selected: _tab == i,
                        badge: i == 0 ? incoming : 0,
                        onTap: () => _open(i),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(child: SafeArea(left: false, child: body)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: _tab == i,
                      button: true,
                      label: i == 0 && incoming > 0 ? '${items[i].$3}, $incoming incoming' : items[i].$3,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => _open(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Badge(
                              isLabelVisible: i == 0 && incoming > 0,
                              label: Text('$incoming'),
                              backgroundColor: p.tone(Tone.red).dot,
                              child: Icon(_tab == i ? items[i].$2 : items[i].$1,
                                  size: 23, color: _tab == i ? p.primary : p.muted),
                            ),
                            const SizedBox(height: 3),
                            Text(items[i].$3,
                                style: cText(11, weight: FontWeight.w600, color: _tab == i ? p.primary : p.muted)),
                          ],
                        ),
                      ),
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

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _RailItem({required this.icon, required this.label, required this.selected, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = ClinicalPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: badge > 0 ? '$label, $badge incoming' : label,
      excludeSemantics: true,
      child: Material(
        color: selected ? p.navyRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 68,
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  backgroundColor: p.tone(Tone.red).dot,
                  child: Icon(icon, size: 22, color: selected ? Colors.white : p.navyMuted),
                ),
                const SizedBox(height: 4),
                Text(label, style: cText(11, weight: FontWeight.w600, color: selected ? Colors.white : p.navyMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
