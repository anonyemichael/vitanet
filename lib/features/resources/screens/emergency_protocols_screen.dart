import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:vitanet/core/providers/shared_state.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/first_aid/screens/first_aid_screen.dart';
import 'package:vitanet/features/resources/widgets/emergency_widgets.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Emergency protocols: a "call first" header, life-threatening protocols and
/// urgent-but-manageable guides, each opening the step-by-step first aid page.
///
/// Live GPS is used to infer the regional emergency number (112 / 911 / 999 /
/// 000 / 193) and to let the user copy their location for the dispatcher.
class EmergencyProtocolsScreen extends ConsumerStatefulWidget {
  const EmergencyProtocolsScreen({super.key});

  @override
  ConsumerState<EmergencyProtocolsScreen> createState() => _EmergencyProtocolsScreenState();
}

/// Backwards compatibility alias for existing router and resource screen bindings.
typedef EmergencyHubScreen = EmergencyProtocolsScreen;

class _EmergencyProtocolsScreenState extends ConsumerState<EmergencyProtocolsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Geolocation & emergency number state
  String _emergencyNumber = '112';
  Position? _currentPosition;
  String _currentAddress = 'Finding your location…';
  bool _isLoadingLocation = true;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Initialises real-time geolocation tracking with proper fallback states
  Future<void> _initLocationTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentAddress = 'Location services are off';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _currentAddress = 'Location permission denied';
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentAddress = 'Location access is disabled in Settings';
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          _currentAddress = 'GPS ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
        _reverseGeocode(position.latitude, position.longitude);
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            _isLoadingLocation = false;
          });
        }
      }, onError: (_) {
        if (mounted) setState(() => _isLoadingLocation = false);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Location unavailable';
          _isLoadingLocation = false;
        });
      }
    }
  }

  /// Reverse geocodes coordinates and infers the regional emergency number.
  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );
      final res = await http.get(url, headers: {'User-Agent': 'VitaNet-Emergency/1.0'}).timeout(
            const Duration(seconds: 3),
          );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final address = data['address'] as Map<String, dynamic>?;
          final countryCode = address?['country_code']?.toString().toLowerCase();

          var localEmergency = '112';
          if (countryCode == 'us' || countryCode == 'ca') {
            localEmergency = '911';
          } else if (countryCode == 'gb' || countryCode == 'uk') {
            localEmergency = '999';
          } else if (countryCode == 'au') {
            localEmergency = '000';
          } else if (countryCode == 'br') {
            localEmergency = '193';
          }

          final road = address?['road'] ?? address?['pedestrian'] ?? address?['suburb'] ?? '';
          final city = address?['city'] ?? address?['town'] ?? address?['village'] ?? address?['county'] ?? '';
          final shortAddress = (road.toString().isNotEmpty && city.toString().isNotEmpty)
              ? '$road, $city'
              : (data['display_name'] ?? 'GPS ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}');

          setState(() {
            _currentAddress = shortAddress.toString();
            _emergencyNumber = localEmergency;
          });
          return;
        }
      }
    } catch (_) {
      // Fall back to raw coordinates below.
    }
    if (mounted) {
      setState(() => _currentAddress = 'GPS ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}');
    }
  }

  void _copyLocationToClipboard() {
    final text = _currentPosition != null
        ? '$_currentAddress (Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude})'
        : _currentAddress;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Location copied. Read it to the dispatcher.'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _openProtocol(FirstAidTip tip) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => EmergencyProtocolDetailScreen(tip: tip, emergencyNumber: _emergencyNumber),
      ),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      try {
        context.go('/resources');
      } catch (_) {}
    }
  }

  List<FirstAidTip> _filter(List<FirstAidTip> tips) {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return tips;
    return tips.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.summary.toLowerCase().contains(q) ||
          (t.cue?.toLowerCase().contains(q) ?? false) ||
          t.steps.any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final resourcesService = ref.watch(dynamicResourcesServiceProvider);

    return Scaffold(
      backgroundColor: p.page,
      body: StreamBuilder<List<FirstAidTip>>(
        stream: resourcesService.streamFirstAidGuides(category: 'All'),
        initialData: FirstAidScreen.tips,
        builder: (context, snapshot) {
          final rawTips = (snapshot.data != null && snapshot.data!.isNotEmpty) ? snapshot.data! : FirstAidScreen.tips;
          final filtered = _filter(rawTips);
          final critical = filtered.where((t) => t.isCritical).toList();
          final minor = filtered.where((t) => !t.isCritical).toList();

          return NotificationListener<ScrollNotification>(
            onNotification: (n) => handleScrollNotification(n, ref),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: EmergencyHeader(
                    emergencyNumber: _emergencyNumber,
                    searchController: _searchController,
                    onSearchChanged: (v) => setState(() => _searchQuery = v),
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    onBack: _goBack,
                    locationText: _currentAddress,
                    isLocating: _isLoadingLocation,
                    onCopyLocation: _copyLocationToClipboard,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.paddingOf(context).bottom + 110),
                  sliver: SliverList.list(
                    children: [
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 40, color: p.faint),
                              const SizedBox(height: 10),
                              Text(
                                'No protocols match "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: VnText.body(15, weight: FontWeight.w600, color: p.ink),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'If someone is in danger, call $_emergencyNumber now.',
                                textAlign: TextAlign.center,
                                style: VnText.body(13, color: p.muted),
                              ),
                            ],
                          ),
                        ),
                      if (critical.isNotEmpty) ...[
                        const VnSectionLabel('Life-threatening', padding: EdgeInsets.zero),
                        const SizedBox(height: 10),
                        for (final tip in critical) ...[
                          CriticalProtocolTile(tip: tip, onTap: () => _openProtocol(tip)),
                          const SizedBox(height: 10),
                        ],
                      ],
                      if (minor.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const VnSectionLabel('Urgent but manageable', padding: EdgeInsets.zero),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 600 ? 3 : 2;
                            final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final tip in minor)
                                  SizedBox(
                                    width: width,
                                    child: MinorProtocolTile(tip: tip, onTap: () => _openProtocol(tip)),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
