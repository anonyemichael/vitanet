import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:vitanet/core/network/backend.dart';
import 'package:vitanet/data/models/user_profile.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/referral_service.dart';

/// A latitude/longitude pair (kept separate from geolocator's Position so
/// tests can override it easily).
class DeviceLocation {
  final double latitude;
  final double longitude;
  const DeviceLocation(this.latitude, this.longitude);
}

final referralServiceProvider = Provider<ReferralService>(
  (ref) => ReferralService(createBackendDio()),
);

/// The device's current location, or null when unavailable / denied /
/// slower than 8 seconds. Never throws.
final currentLocationProvider = FutureProvider.autoDispose<DeviceLocation?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    ).timeout(const Duration(seconds: 8));
    return DeviceLocation(pos.latitude, pos.longitude);
  } catch (e) {
    debugPrint('Referral location unavailable: $e');
    return null;
  }
});

/// Hospitals registered with VitaNet, nearest first when location is known
/// (alphabetical otherwise). Refresh with `ref.invalidate`.
final nearbyFacilitiesProvider = FutureProvider.autoDispose<List<Facility>>((ref) async {
  final loc = await ref.watch(currentLocationProvider.future);
  return ref.read(referralServiceProvider).listFacilities(lat: loc?.latitude, lng: loc?.longitude);
});

/// The signed-in user's (including guests') referrals, newest first.
/// Empty when nobody is signed in. Refresh with [refreshReferrals].
final myReferralsProvider = FutureProvider<List<Referral>>((ref) async {
  final uid = ref.watch(authProvider.select((s) => s.user?.uid));
  if (uid == null) return const [];
  return ref.read(referralServiceProvider).mine();
});

/// The referral that is still new or accepted, if any.
final activeReferralProvider = Provider<Referral?>((ref) {
  final list = ref.watch(myReferralsProvider).valueOrNull ?? const <Referral>[];
  for (final r in list) {
    if (r.isOpen) return r;
  }
  return null;
});

/// Profile used to prefill the shared summary (read-only view of the
/// user's health profile; null for guests without one).
final referralProfileProvider = Provider<UserProfile?>((ref) => ref.watch(userProfileProvider));

/// Latest device vitals used to prefill the shared summary.
final referralVitalsProvider = Provider<Map<String, double>>((ref) => ref.watch(liveVitalsProvider));

/// Id of the referral sent from the current triage result, so its outcome
/// (including a decline) stays visible on that screen.
final sessionReferralIdProvider = StateProvider<String?>((ref) => null);

/// Re-fetch my referrals.
void refreshReferrals(WidgetRef ref) => ref.invalidate(myReferralsProvider);
