import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/admin/models/portal_models.dart';
import 'package:vitanet/features/admin/services/hospital_api_service.dart';

final hospitalApiProvider = Provider<HospitalApiService>((ref) => HospitalApiService());

/// Where a signed-in user stands with the hospital portal.
enum StaffAccessKind { none, pending, rejected, suspended, needsHospital, approved }

class StaffAccess {
  final StaffAccessKind kind;
  final StaffMe? me;
  const StaffAccess(this.kind, [this.me]);

  static const none = StaffAccess(StaffAccessKind.none);

  factory StaffAccess.fromMe(StaffMe? me) {
    if (me == null) return none;
    return switch (me.status) {
      StaffStatus.pending => StaffAccess(StaffAccessKind.pending, me),
      StaffStatus.rejected => StaffAccess(StaffAccessKind.rejected, me),
      StaffStatus.suspended => StaffAccess(StaffAccessKind.suspended, me),
      StaffStatus.approved =>
        StaffAccess(me.hospitalId == null ? StaffAccessKind.needsHospital : StaffAccessKind.approved, me),
    };
  }

  /// Staff who belong in the portal rather than the patient app.
  bool get isPortalUser =>
      kind == StaffAccessKind.approved || kind == StaffAccessKind.needsHospital || kind == StaffAccessKind.pending;
}

/// Staff status for the signed-in (non-anonymous) user, from GET /staff/me.
/// This — not the Firestore profile role — decides portal access.
final staffAccessProvider = FutureProvider<StaffAccess>((ref) async {
  final uid = ref.watch(authProvider.select(
    (s) => s.status == AuthStatus.authenticated ? s.user?.uid : null,
  ));
  if (uid == null) return StaffAccess.none;
  final me = await ref.watch(hospitalApiProvider).getStaffMe();
  return StaffAccess.fromMe(me);
});

/// Router rules for staff-related paths. [access] is null while unknown
/// (loading or failed), in which case nothing is redirected and the portal
/// gate shows the loading / error state itself.
String? staffRouteRedirect(String path, StaffAccess? access) {
  if (access == null) return null;
  if (path == '/admin' || path.startsWith('/admin/')) {
    return access.kind == StaffAccessKind.none ? '/home' : null;
  }
  if (path == '/home' || path == '/chat') {
    return access.isPortalUser ? '/admin' : null;
  }
  if (path == '/') return access.isPortalUser ? '/admin' : '/home';
  return null;
}

// ─── Portal data ───

final patientCasesProvider = FutureProvider.autoDispose<List<PatientHospitalCase>>(
  (ref) async {
    final uid = ref.watch(authProvider.select((s) => s.user?.uid));
    if (uid == null) return const [];
    return ref.watch(hospitalApiProvider).getPatientCases();
  },
);

final facilitiesProvider = FutureProvider.autoDispose<List<Facility>>(
  (ref) => ref.watch(hospitalApiProvider).listFacilities(),
);

/// Server-side hospital search (name or address); '' lists all (up to 200).
final facilitySearchProvider = FutureProvider.autoDispose.family<List<Facility>, String>(
  (ref, query) async {
    // Small debounce so typing doesn't fire a request per keystroke.
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (cancelled) return const [];
    return ref.watch(hospitalApiProvider).listFacilities(query: query);
  },
);

final dashboardProvider = FutureProvider.autoDispose<Dashboard>(
  (ref) => ref.watch(hospitalApiProvider).getDashboard(),
);

/// Referrals by status ('new', 'accepted', 'declined').
final referralsProvider = FutureProvider.autoDispose.family<List<Referral>, String>(
  (ref, status) => ref.watch(hospitalApiProvider).listReferrals(status: status),
);

final referralProvider = FutureProvider.autoDispose.family<Referral, String>(
  (ref, id) => ref.watch(hospitalApiProvider).getReferral(id),
);

typedef CaseQuery = ({String status, bool mine});

final casesProvider = FutureProvider.autoDispose.family<List<PortalCase>, CaseQuery>(
  (ref, q) => ref.watch(hospitalApiProvider).listCases(status: q.status, mine: q.mine),
);

final caseProvider = FutureProvider.autoDispose.family<PortalCase, String>(
  (ref, id) => ref.watch(hospitalApiProvider).getCase(id),
);

final alertsProvider = FutureProvider.autoDispose<List<PortalAlert>>(
  (ref) => ref.watch(hospitalApiProvider).listAlerts(),
);

final capacityProvider = FutureProvider.autoDispose<Capacity>(
  (ref) => ref.watch(hospitalApiProvider).getCapacity(),
);

final teamProvider = FutureProvider.autoDispose<List<TeamMember>>(
  (ref) => ref.watch(hospitalApiProvider).listTeam(),
);

final myHospitalProvider = FutureProvider.autoDispose<Facility>(
  (ref) => ref.watch(hospitalApiProvider).getMyHospital(),
);

final auditProvider = FutureProvider.autoDispose<List<AuditEntry>>(
  (ref) => ref.watch(hospitalApiProvider).listAudit(),
);

/// Refresh everything that a referral / case / capacity change can affect.
void invalidatePortalData(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(referralsProvider);
  ref.invalidate(referralProvider);
  ref.invalidate(casesProvider);
  ref.invalidate(caseProvider);
  ref.invalidate(alertsProvider);
  ref.invalidate(capacityProvider);
}
