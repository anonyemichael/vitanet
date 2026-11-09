import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/features/portal/board/referral_view.dart';
import 'package:vitanet/features/portal/record/case_record_view.dart';

/// Desk layouts start at this width (navy rail + two panes).
const kDeskBreakpoint = 1000.0;

bool isDesk(BuildContext context) => MediaQuery.sizeOf(context).width >= kDeskBreakpoint;

/// What the desk detail pane shows.
typedef DeskSelection = ({String kind, String id}); // kind: referral | case

final deskSelectionProvider = StateProvider<DeskSelection?>((ref) => null);

/// Marks a subtree that has a detail pane next to it (desk Board / Patients).
/// Inside it, opening a referral or case fills the pane instead of pushing a
/// page.
class DetailPaneScope extends InheritedWidget {
  const DetailPaneScope({super.key, required super.child});

  static bool hasPane(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPaneScope>() != null;

  @override
  bool updateShouldNotify(DetailPaneScope oldWidget) => false;
}

void openReferral(BuildContext context, WidgetRef ref, String id) {
  if (DetailPaneScope.hasPane(context)) {
    ref.read(deskSelectionProvider.notifier).state = (kind: 'referral', id: id);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReferralPage(referralId: id)));
}

void openCase(BuildContext context, WidgetRef ref, String id) {
  if (DetailPaneScope.hasPane(context)) {
    ref.read(deskSelectionProvider.notifier).state = (kind: 'case', id: id);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CaseRecordPage(caseId: id)));
}

/// After accepting on a phone, replace the referral page with the new record;
/// on desk, show the record in the pane.
void showCaseAfterAccept(BuildContext context, WidgetRef ref, String caseId) {
  if (DetailPaneScope.hasPane(context)) {
    ref.read(deskSelectionProvider.notifier).state = (kind: 'case', id: caseId);
    return;
  }
  Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => CaseRecordPage(caseId: caseId)));
}
