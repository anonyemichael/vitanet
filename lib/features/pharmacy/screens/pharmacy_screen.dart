import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:vitanet/core/utils/launch_helpers.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Find care nearby: live location, nearby pharmacies / hospitals / clinics
/// from OpenStreetMap, filter chips and Call / Directions actions. Falls back
/// to map searches when location or listings are unavailable.
class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

enum _LoadState { locating, loading, ready, noLocation, failed }

class _PharmacyScreenState extends State<PharmacyScreen> {
  final _controller = TextEditingController();

  static const _filters = <(String, String)>[
    ('Open now', 'pharmacy open now'),
    ('Pharmacies', 'pharmacy near me'),
    ('24 hours', '24 hour pharmacy near me'),
    ('Emergency room', 'emergency room hospital near me'),
    ('Urgent care', 'urgent care near me'),
    ('Drive-thru', 'drive thru pharmacy near me'),
  ];
  String _filter = 'Pharmacies';

  _LoadState _state = _LoadState.locating;
  String _statusMessage = '';
  Position? _position;
  List<_Place> _places = [];

  @override
  void initState() {
    super.initState();
    _locateAndLoad();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Incremented on every locate attempt so a late answer (e.g. a browser
  /// permission prompt accepted after the timeout) can't overwrite a newer
  /// state.
  int _locateRun = 0;

  /// Upper bound for the whole permission + GPS step. Browsers never resolve
  /// the permission request while the prompt is left unanswered, so without
  /// this the screen would spin forever.
  static const _locateTimeout = Duration(seconds: 8);

  Future<void> _locateAndLoad() async {
    final run = ++_locateRun;
    setState(() => _state = _LoadState.locating);
    final Position pos;
    try {
      pos = await _getPosition().timeout(_locateTimeout);
    } on _LocationUnavailable catch (e) {
      if (run == _locateRun) _fail(_LoadState.noLocation, e.message);
      return;
    } on TimeoutException {
      if (run == _locateRun) {
        _fail(
          _LoadState.noLocation,
          "We couldn't get your location. Allow location access and retry, or search for a town or postcode above.",
        );
      }
      return;
    } catch (_) {
      if (run == _locateRun) {
        _fail(_LoadState.noLocation, 'We could not get your location. You can still search by area above or in Maps.');
      }
      return;
    }
    if (!mounted || run != _locateRun) return;
    setState(() {
      _position = pos;
      _state = _LoadState.loading;
    });
    await _loadPlaces(pos);
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _LocationUnavailable('Turn on location to see places near you, or search by area above.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const _LocationUnavailable('Location permission is off. You can still search by area above or in Maps.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _locateTimeout),
    );
  }
  void _fail(_LoadState state, String message) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _statusMessage = message;
    });
  }

  Future<void> _loadPlaces(Position pos) async {
    final query = '[out:json][timeout:15];('
        'node["amenity"~"^(pharmacy|hospital|clinic|doctors)\$"](around:5000,${pos.latitude},${pos.longitude});'
        'way["amenity"~"^(pharmacy|hospital|clinic)\$"](around:5000,${pos.latitude},${pos.longitude});'
        ');out center tags 60;';
    try {
      final res = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            headers: {'User-Agent': 'VitaNet/1.0'},
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 18));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List?) ?? const [];
      final now = DateTime.now();
      final places = <_Place>[];
      for (final e in elements) {
        final place = _Place.fromOverpass(e as Map<String, dynamic>, pos, now);
        if (place != null) places.add(place);
      }
      places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      if (!mounted) return;
      setState(() {
        _places = places;
        _state = _LoadState.ready;
      });
    } catch (_) {
      _fail(_LoadState.failed, 'Nearby listings are unavailable right now.');
    }
  }

  List<_Place> get _visible {
    final q = _controller.text.trim().toLowerCase();
    Iterable<_Place> list = _places;
    switch (_filter) {
      case 'Open now':
        list = list.where((p) => p.openNow == true);
      case 'Pharmacies':
        list = list.where((p) => p.kind == _PlaceKind.pharmacy);
      case '24 hours':
        list = list.where((p) => p.is24h);
      case 'Emergency room':
        list = list.where((p) => p.kind == _PlaceKind.hospital);
      case 'Urgent care':
        list = list.where((p) => p.kind == _PlaceKind.clinic);
      case 'Drive-thru':
        list = list.where((p) => p.driveThrough);
    }
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.address.toLowerCase().contains(q));
    }
    return list.take(30).toList();
  }

  String get _filterQuery => _filters.firstWhere((f) => f.$1 == _filter).$2;

  Future<void> _searchMaps([String? query]) async {
    final q = (query ?? _controller.text).trim();
    await LaunchHelpers.openPharmacyOrSnack(context, q.isEmpty ? _filterQuery : q);
  }

  void _directions(_Place place) {
    LaunchHelpers.openWeb(
      context,
      'https://www.google.com/maps/dir/?api=1&destination=${place.lat},${place.lon}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final visible = _visible;
    final top = MediaQuery.paddingOf(context).top;

    return vnReadableWidth(Scaffold(
      backgroundColor: p.page,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 330 + top,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _MapHeader(position: _position, places: visible.take(3).toList()),
                  ),
                  Positioned(
                    top: top + 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _Floating(
                          child: VnIconButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Back',
                            size: 48,
                            iconSize: 26,
                            background: Colors.white,
                            foreground: const Color(0xFF0F172A),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _Floating(child: _buildSearch())),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 40,
                    child: _Floating(
                      child: VnIconButton(
                        icon: Icons.near_me_rounded,
                        tooltip: 'Use my current location',
                        size: 48,
                        background: Colors.white,
                        foreground: const Color(0xFF2563EB),
                        onPressed: _locateAndLoad,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: BoxDecoration(
                  color: p.page,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.fromLTRB(0, 10, 0, MediaQuery.paddingOf(context).bottom + 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: p.isDark ? const Color(0xFF404040) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          for (final f in _filters) ...[
                            _FilterChip(
                              label: f.$1,
                              selected: f.$1 == _filter,
                              onTap: () => setState(() => _filter = f.$1),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildBody(p, visible),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ), maxWidth: 960, background: p.page);
  }

  Widget _buildSearch() {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (q) => _searchMaps(q),
              style: VnText.body(14, color: const Color(0xFF0F172A)),
              cursorColor: const Color(0xFF0F766E),
              decoration: InputDecoration(
                hintText: 'Search pharmacies, area or store',
                hintStyle: VnText.body(14, color: const Color(0xFF64748B)),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            VnIconButton(
              icon: Icons.map_outlined,
              tooltip: 'Search in Maps',
              iconSize: 20,
              foreground: const Color(0xFF0F766E),
              background: Colors.white,
              onPressed: () => _searchMaps(),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(VnPalette p, List<_Place> visible) {
    switch (_state) {
      case _LoadState.locating:
      case _LoadState.loading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: p.brand),
              const SizedBox(height: 12),
              Text(
                _state == _LoadState.locating ? 'Finding your location…' : 'Finding places near you…',
                style: VnText.body(14, color: p.muted),
              ),
            ],
          ),
        );
      case _LoadState.noLocation:
      case _LoadState.failed:
        return _FallbackCard(
          message: _statusMessage,
          filter: _filter,
          onSearch: () => _searchMaps(_filterQuery),
          onRetry: _locateAndLoad,
        );
      case _LoadState.ready:
        if (visible.isEmpty) {
          return _FallbackCard(
            message: _filter == 'Open now'
                ? 'No nearby listings show opening hours that match right now.'
                : 'No "${_filter.toLowerCase()}" listed within 5 km.',
            filter: _filter,
            onSearch: () => _searchMaps(_filterQuery),
            onRetry: _locateAndLoad,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final place in visible) ...[
              _PlaceCard(
                place: place,
                onCall: place.phone == null ? null : () => LaunchHelpers.dialOrSnack(context, place.phone!),
                onDirections: () => _directions(place),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              'Places from OpenStreetMap. Opening hours may be out of date, so call ahead.',
              style: VnText.body(12, color: p.muted, height: 1.5),
            ),
          ],
        );
    }
  }
}

class _LocationUnavailable implements Exception {
  final String message;
  const _LocationUnavailable(this.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

enum _PlaceKind { pharmacy, hospital, clinic }

class _Place {
  final String name;
  final _PlaceKind kind;
  final double lat;
  final double lon;
  final double distanceMeters;
  final double bearing;
  final String address;
  final String? phone;
  final bool is24h;
  final bool driveThrough;
  final bool emergency;
  final bool? openNow;
  final String? closesAt;

  const _Place({
    required this.name,
    required this.kind,
    required this.lat,
    required this.lon,
    required this.distanceMeters,
    required this.bearing,
    required this.address,
    required this.phone,
    required this.is24h,
    required this.driveThrough,
    required this.emergency,
    required this.openNow,
    required this.closesAt,
  });

  static _Place? fromOverpass(Map<String, dynamic> e, Position me, DateTime now) {
    final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = tags['name']?.toString();
    if (name == null || name.isEmpty) return null;
    final lat = (e['lat'] ?? (e['center'] as Map?)?['lat']) as num?;
    final lon = (e['lon'] ?? (e['center'] as Map?)?['lon']) as num?;
    if (lat == null || lon == null) return null;

    final amenity = tags['amenity']?.toString() ?? '';
    final kind = amenity == 'pharmacy'
        ? _PlaceKind.pharmacy
        : amenity == 'hospital'
            ? _PlaceKind.hospital
            : _PlaceKind.clinic;
    final hours = tags['opening_hours']?.toString();
    final open = OpeningHours.evaluate(hours, now);
    final street = [tags['addr:housenumber'], tags['addr:street']].whereType<Object>().join(' ');
    final area = tags['addr:suburb'] ?? tags['addr:city'] ?? tags['addr:district'];
    final address = [if (street.isNotEmpty) street, ?area?.toString()].join(', ');

    return _Place(
      name: name,
      kind: kind,
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      distanceMeters: Geolocator.distanceBetween(me.latitude, me.longitude, lat.toDouble(), lon.toDouble()),
      bearing: Geolocator.bearingBetween(me.latitude, me.longitude, lat.toDouble(), lon.toDouble()),
      address: address,
      phone: (tags['phone'] ?? tags['contact:phone'])?.toString().split(';').first.trim(),
      is24h: hours?.trim() == '24/7',
      driveThrough: tags['drive_through']?.toString() == 'yes',
      emergency: tags['emergency']?.toString() == 'yes',
      openNow: open.$1,
      closesAt: open.$2,
    );
  }

  String get distanceLabel {
    final km = distanceMeters / 1000;
    final distance = km < 1 ? '${(distanceMeters / 10).round() * 10} m' : '${km.toStringAsFixed(1)} km';
    final walk = distanceMeters <= 1200;
    final minutes = math.max(1, (distanceMeters / (walk ? 80 : 450)).round());
    return '$distance · $minutes min ${walk ? 'walk' : 'drive'}';
  }

  String get shortDistance {
    final km = distanceMeters / 1000;
    return km < 1 ? '${(distanceMeters / 10).round() * 10} m' : '${km.toStringAsFixed(1)} km';
  }

  String get openLabel {
    if (is24h) return 'Open 24 hours';
    if (openNow == true) return closesAt != null ? 'Open · closes $closesAt' : 'Open now';
    if (openNow == false) return 'Closed now';
    return 'Hours not listed';
  }
}

/// Minimal evaluator for the common OpenStreetMap `opening_hours` forms:
/// "24/7", "08:00-20:00", "Mo-Fr 08:00-20:00; Sa 09:00-14:00", "Mo,We 09:00-12:00,14:00-18:00".
/// Returns (isOpen, closingTime) or (null, null) when it cannot be read.
class OpeningHours {
  OpeningHours._();

  static const _days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  static (bool?, String?) evaluate(String? raw, DateTime now) {
    if (raw == null || raw.trim().isEmpty) return (null, null);
    final text = raw.trim();
    if (text == '24/7') return (true, null);
    final today = _days[now.weekday - 1];
    final minutesNow = now.hour * 60 + now.minute;
    var matchedToday = false;
    for (final rule in text.split(';')) {
      final r = rule.trim();
      if (r.isEmpty) continue;
      final m = RegExp(r'^((?:[A-Z][a-z](?:-[A-Z][a-z])?,?)+)?\s*(.*)$').firstMatch(r);
      if (m == null) return (null, null);
      final daysPart = m.group(1);
      final timesPart = (m.group(2) ?? '').trim();
      if (daysPart != null && !_dayMatches(daysPart, today)) continue;
      if (timesPart.toLowerCase() == 'off' || timesPart.toLowerCase() == 'closed') {
        matchedToday = true;
        continue;
      }
      matchedToday = true;
      for (final span in timesPart.split(',')) {
        final t = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$').firstMatch(span.trim());
        if (t == null) return (null, null);
        final start = int.parse(t.group(1)!) * 60 + int.parse(t.group(2)!);
        var end = int.parse(t.group(3)!) * 60 + int.parse(t.group(4)!);
        if (end <= start) end += 24 * 60;
        if (minutesNow >= start && minutesNow < end) {
          return (true, '${t.group(3)!.padLeft(2, '0')}:${t.group(4)}');
        }
      }
    }
    return matchedToday ? (false, null) : (null, null);
  }

  static bool _dayMatches(String daysPart, String today) {
    final idx = _days.indexOf(today);
    for (final token in daysPart.split(',')) {
      final t = token.trim();
      if (t.isEmpty) continue;
      if (t.contains('-')) {
        final parts = t.split('-');
        final a = _days.indexOf(parts[0]);
        final b = _days.indexOf(parts[1]);
        if (a < 0 || b < 0) continue;
        if (a <= b ? (idx >= a && idx <= b) : (idx >= a || idx <= b)) return true;
      } else if (t == today) {
        return true;
      }
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Floating extends StatelessWidget {
  final Widget child;
  const _Floating({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

/// Stylised map drawn like the design, with the user at the centre and the
/// nearest places pinned by real bearing and (scaled) distance.
class _MapHeader extends StatelessWidget {
  final Position? position;
  final List<_Place> places;
  const _MapHeader({required this.position, required this.places});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Semantics(
      label: 'Map of places near you',
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            final center = Offset(w / 2, top + (h - top) * 0.5);
            final maxDist = places.isEmpty
                ? 1.0
                : places.map((p) => p.distanceMeters).reduce(math.max).clamp(200.0, double.infinity);
            final radius = math.min(w, h - top) * 0.36;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapPainter())),
                for (var i = 0; i < places.length; i++)
                  Builder(builder: (context) {
                    final pl = places[i];
                    final rad = pl.bearing * math.pi / 180;
                    final dist = (pl.distanceMeters / maxDist) * radius;
                    final dx = center.dx + math.sin(rad) * dist;
                    final dy = center.dy - math.cos(rad) * dist;
                    return Positioned(
                      left: (dx - 36).clamp(8.0, w - 90),
                      top: (dy - 16).clamp(top + 72, h - 60),
                      child: _MapPin(place: pl, primary: i == 0),
                    );
                  }),
                if (position != null)
                  Positioned(
                    left: center.dx - 21,
                    top: center.dy - 21,
                    child: Semantics(
                      label: 'You are here',
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(color: Color(0x2E2563EB), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 330;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEEF2EE));
    final park = Path()
      ..moveTo(250 * sx, 0)
      ..cubicTo(270 * sx, 80 * sy, 330 * sx, 120 * sy, 390 * sx, 140 * sy)
      ..lineTo(390 * sx, 0)
      ..close();
    canvas.drawPath(park, Paint()..color = const Color(0xFFCDE7D8));
    final water = Path()
      ..moveTo(0, 250 * sy)
      ..cubicTo(80 * sx, 230 * sy, 120 * sx, 280 * sy, 200 * sx, 330 * sy)
      ..lineTo(0, 330 * sy)
      ..close();
    canvas.drawPath(water, Paint()..color = const Color(0xFFBFDBFE));
    void road(double x1, double y1, double x2, double y2, double width, Color color) {
      canvas.drawLine(
        Offset(x1 * sx, y1 * sy),
        Offset(x2 * sx, y2 * sy),
        Paint()
          ..color = color
          ..strokeWidth = width,
      );
    }

    road(-10, 120, 400, 90, 14, Colors.white);
    road(-10, 210, 400, 190, 10, Colors.white);
    road(120, -10, 150, 340, 12, Colors.white);
    road(290, -10, 260, 340, 8, Colors.white);
    road(-10, 120, 400, 90, 4, const Color(0xFFFDE68A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPin extends StatelessWidget {
  final _Place place;
  final bool primary;
  const _MapPin({required this.place, required this.primary});

  @override
  Widget build(BuildContext context) {
    final hospital = place.kind == _PlaceKind.hospital;
    final bg = hospital ? const Color(0xFFB91C1C) : (primary ? const Color(0xFF0F766E) : Colors.white);
    final fg = hospital || primary ? Colors.white : const Color(0xFF0F766E);
    return Semantics(
      label: '${place.name}, ${place.shortDistance}',
      excludeSemantics: true,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x330F172A), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hospital ? Icons.add_rounded : Icons.medication_rounded, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(hospital ? 'A&E' : place.shortDistance, style: VnText.body(12, weight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.ink : p.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? p.ink : p.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label, style: VnText.body(13, weight: FontWeight.w600, color: selected ? p.page : p.ink)),
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final _Place place;
  final VoidCallback? onCall;
  final VoidCallback onDirections;
  const _PlaceCard({required this.place, required this.onCall, required this.onDirections});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final hospital = place.kind == _PlaceKind.hospital;
    final openColor = place.openNow == false
        ? p.danger
        : (place.openNow == true || place.is24h)
            ? (p.isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
            : p.muted;
    final subtitle = [
      if (place.address.isNotEmpty) place.address,
      if (hospital && place.emergency) 'A&E',
      if (place.kind == _PlaceKind.clinic) 'Clinic',
    ].join(' · ');
    return VnCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VnIconTile(
                icon: hospital
                    ? Icons.local_hospital_outlined
                    : place.kind == _PlaceKind.clinic
                        ? Icons.medical_services_outlined
                        : Icons.medication_rounded,
                bg: hospital ? const Color(0xFFFEE2E2) : const Color(0xFFCCFBF1),
                fg: hospital ? const Color(0xFFB91C1C) : const Color(0xFF0F766E),
                size: 44,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: VnText.body(15, weight: FontWeight.w700, color: p.ink)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle, style: VnText.body(13, color: p.muted)),
                    ],
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(place.openLabel, style: VnText.body(12, weight: FontWeight.w600, color: openColor)),
                        Text(place.distanceLabel, style: VnText.body(12, weight: FontWeight.w600, color: p.muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: VnOutlineButton(
                  label: onCall == null ? 'No phone listed' : 'Call',
                  icon: Icons.phone_outlined,
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  background: p.surfaceAlt,
                  borderColor: Colors.transparent,
                  foreground: onCall == null ? p.faint : p.ink,
                  onPressed: onCall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VnButton(
                  label: 'Directions',
                  icon: Icons.near_me_rounded,
                  height: 44,
                  radius: 12,
                  fontSize: 13,
                  onPressed: onDirections,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FallbackCard extends StatelessWidget {
  final String message;
  final String filter;
  final VoidCallback onSearch;
  final VoidCallback onRetry;
  const _FallbackCard({required this.message, required this.filter, required this.onSearch, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return VnCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const VnIconTile(icon: Icons.map_outlined, bg: Color(0xFFCCFBF1), fg: Color(0xFF0F766E), size: 44, radius: 14),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: VnText.body(14, color: p.ink, height: 1.45))),
            ],
          ),
          const SizedBox(height: 12),
          VnButton(
            label: 'Search "${filter.toLowerCase()}" in Maps',
            icon: Icons.open_in_new_rounded,
            height: 48,
            fontSize: 14,
            onPressed: onSearch,
          ),
          const SizedBox(height: 8),
          VnOutlineButton(label: 'Try again', height: 44, fontSize: 14, onPressed: onRetry),
        ],
      ),
    );
  }
}
