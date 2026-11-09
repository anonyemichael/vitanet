import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/portal/data/hospital_api_service.dart';
import 'package:vitanet/features/portal/data/portal_models.dart';

final hospitalApiProvider = Provider<HospitalApiService>((ref) => HospitalApiService());

/// Active workspace preference: personal health vs clinical hospital portal.
enum AppWorkspace { personal, hospital }

class ActiveWorkspaceNotifier extends Notifier<AppWorkspace> {
  static const _key = 'vitanet_active_workspace';

  @override
  AppWorkspace build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final val = prefs?.getString(_key);
    if (val == 'hospital') return AppWorkspace.hospital;
    return AppWorkspace.personal;
  }

  Future<void> setWorkspace(AppWorkspace ws) async {
    state = ws;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(_key, ws == AppWorkspace.hospital ? 'hospital' : 'personal');
  }
}

final activeWorkspaceProvider =
    NotifierProvider<ActiveWorkspaceNotifier, AppWorkspace>(ActiveWorkspaceNotifier.new);

final preferredWorkspaceProvider =
    Provider<AppWorkspace>((ref) => ref.watch(activeWorkspaceProvider));

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

/// The router's rules for a signed-in user (the router itself calls this, so
/// these are the rules the app really uses). [access] is null while unknown
/// (loading or failed): nothing is forced and the portal gate shows the
/// loading / error state itself. Staff who chose the personal workspace stay
/// in the patient app; patients are never let into /admin.
String? staffRouteRedirect(String path, StaffAccess? access, {AppWorkspace workspace = AppWorkspace.hospital}) {
  if (path == '/admin' || path.startsWith('/admin/')) {
    return access?.kind == StaffAccessKind.none ? '/home' : null;
  }
  final toPortal = workspace == AppWorkspace.hospital && (access?.isPortalUser ?? false);
  if (path == '/') return toPortal ? '/admin' : '/home';
  if ((path == '/home' || path == '/chat') && toPortal) return '/admin';
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

/// Referrals by status; a comma list is allowed (e.g. 'accepted,arrived').
final referralsProvider = FutureProvider.autoDispose.family<List<Referral>, String>(
  (ref, status) => ref.watch(hospitalApiProvider).listReferrals(status: status),
);

final referralProvider = FutureProvider.autoDispose.family<Referral, String>(
  (ref, id) => ref.watch(hospitalApiProvider).getReferral(id),
);

/// `status` may be a comma list, e.g. [activeCaseStatuses].
typedef CaseQuery = ({String status, bool mine});

const activeCaseStatuses = 'expected,waiting,treatment';

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

/// Whether the live connection to the server is up (drives the "Live" dot and
/// the slow fallback refresh).
final portalLiveConnectedProvider = StateProvider<bool>((ref) => false);

/// Refresh what a server event of [type] can affect (see PortalLive).
void invalidateForEvent(Ref ref, String type, String? id) {
  switch (type) {
    case 'referral':
      ref.invalidate(referralsProvider);
      if (id != null) ref.invalidate(referralProvider(id));
      ref.invalidate(dashboardProvider);
    case 'case':
      ref.invalidate(casesProvider);
      if (id != null) ref.invalidate(caseProvider(id));
      ref.invalidate(dashboardProvider);
    case 'alert':
      ref.invalidate(alertsProvider);
    case 'capacity':
      ref.invalidate(capacityProvider);
      ref.invalidate(myHospitalProvider);
      ref.invalidate(dashboardProvider);
    case 'team':
      ref.invalidate(capacityProvider);
      ref.invalidate(teamProvider);
      ref.invalidate(dashboardProvider);
  }
}

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
