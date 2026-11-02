import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/features/resources/widgets/resource_media.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

/// Devices & data: wearable sync status, health platforms (Health Connect /
/// Apple Health) and the data types VitaNet reads.
class DeviceConnectionScreen extends ConsumerStatefulWidget {
  final String metricId;

  const DeviceConnectionScreen({super.key, required this.metricId});

  @override
  ConsumerState<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends ConsumerState<DeviceConnectionScreen> {
  bool _isSyncing = false;
  bool _connected = false;
  DateTime? _lastSync;
  final Set<String> _syncedKeys = {};

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String get _platformName => _isIos ? 'Apple Health' : 'Health Connect';

  @override
  void initState() {
    super.initState();
    // Reflect vitals already pulled in this session.
    final vitals = ref.read(liveVitalsProvider);
    if (vitals.isNotEmpty) {
      _connected = true;
      _syncedKeys.addAll(vitals.keys);
    }
  }

  /// Health values arrive as "NumericHealthValue - numericValue: 72".
  static double? _parse(Object? value) {
    final text = value?.toString() ?? '';
    final direct = double.tryParse(text);
    if (direct != null) return direct;
    final m = RegExp(r'(-?\d+(?:\.\d+)?)\s*$').firstMatch(text);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  Future<void> _syncDevice() async {
    setState(() => _isSyncing = true);
    final service = ref.read(healthServiceProvider);
    final hasPermissions = await service.requestPermissions();
    var count = 0;
    if (hasPermissions) {
      try {
        final biometrics = await service.fetchBiometrics();
        if (mounted) {
          biometrics.forEach((key, value) {
            final v = _parse(value);
            if (v != null) {
              ref.read(liveVitalsProvider.notifier).setVital(key, v);
              _syncedKeys.add(key);
              count++;
            }
          });
        }
      } catch (e) {
        debugPrint('Error fetching immediate biometrics: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (hasPermissions) {
        _connected = true;
        _lastSync = DateTime.now();
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          hasPermissions
              ? (count > 0 ? 'Synced $count readings from $_platformName' : 'Connected. No new readings in the last 2 days.')
              : 'Could not get $_platformName permission. Install it or check its settings.',
        ),
      ));
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = VnPalette.of(ctx);
        return VnDialog(
          children: [
            const VnIconTile(icon: Icons.link_off_rounded, bg: Color(0xFFFEE2E2), fg: Color(0xFFB91C1C), size: 56, radius: 18, iconSize: 26),
            Text('Disconnect your device?', style: VnText.heading(20, color: p.ink)),
            Text(
              'VitaNet will stop using readings from $_platformName on this phone. You can remove its access completely in $_platformName.',
              style: VnText.body(14, color: p.inkSoft, height: 1.55),
            ),
            Row(
              children: [
                Expanded(
                  child: VnOutlineButton(
                    label: 'Cancel',
                    background: p.surfaceAlt,
                    borderColor: Colors.transparent,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: VnButton(
                    label: 'Disconnect',
                    height: 52,
                    fontSize: 15,
                    background: p.danger,
                    foreground: Colors.white,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() {
      _connected = false;
      _lastSync = null;
      _syncedKeys.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Disconnected. Revoke access in $_platformName if you no longer want to share.'),
      action: SnackBarAction(label: 'Open', onPressed: _openHealthConnectSettings),
    ));
  }

  Future<void> _openHealthConnectSettings() async {
    final url = Uri.parse(_isIos ? 'x-apple-health://' : 'market://details?id=com.google.android.apps.healthdata');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(
          Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Could not launch Health Connect: $e');
    }
  }

  void _pairCuff() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text('Pair your cuff in its own app (Omron, Withings…), then turn on sharing with $_platformName.'),
    ));
    _openHealthConnectSettings();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      try {
        context.go('/home');
      } catch (_) {}
    }
  }

  String get _syncText {
    if (!_connected) return 'Not connected yet';
    final t = _lastSync;
    if (t == null) return 'Connected';
    final mins = DateTime.now().difference(t).inMinutes;
    return 'Connected · synced ${mins < 1 ? 'just now' : '$mins min ago'}';
  }

  static const _typeChips = <String, (String, Color, Color)>{
    'heart_rate': ('Heart rate', Color(0xFFFFE4E6), Color(0xFF9F1239)),
    'blood_oxygen': ('SpO2', Color(0xFFE0F2FE), Color(0xFF075985)),
    'systolic_bp': ('Blood pressure', Color(0xFFE0E7FF), Color(0xFF3730A3)),
    'temperature': ('Temperature', Color(0xFFFFEDD5), Color(0xFF9A3412)),
    'respiratory_rate': ('Breathing', Color(0xFFD1FAE5), Color(0xFF065F46)),
  };

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    final ok = p.isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
    final chips = _typeChips.entries.where((e) => _syncedKeys.contains(e.key)).map((e) => e.value).toList();

    return Scaffold(
      backgroundColor: p.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                VnTopBar(title: 'Devices & data', onBack: _back),
                const SizedBox(height: 18),
                VnCard(
                  radius: 22,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: VnPhoto(VnPhotos.smartwatchWrist, alignment: Alignment(-0.1, 0), cacheWidth: 200),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your watch or tracker', style: VnText.body(16, weight: FontWeight.w700, color: p.ink)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _connected ? const Color(0xFF10B981) : p.faint,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(_syncText,
                                          style: VnText.body(13, weight: FontWeight.w600, color: _connected ? ok : p.muted)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (chips.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in chips)
                              VnTag(
                                label: c.$1,
                                bg: c.$2,
                                fg: c.$3,
                                fontSize: 12,
                                weight: FontWeight.w600,
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              ),
                          ],
                        )
                      else
                        Text(
                          'Link your watch app (Fitbit, Garmin, Samsung Health…) to $_platformName, then sync.',
                          style: VnText.body(13, color: p.muted, height: 1.45),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: VnButton(
                              label: 'Sync now',
                              height: 44,
                              radius: 12,
                              fontSize: 14,
                              loading: _isSyncing,
                              background: p.surfaceAlt,
                              foreground: p.ink,
                              onPressed: _syncDevice,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: VnOutlineButton(
                              label: 'Disconnect',
                              height: 44,
                              radius: 12,
                              fontSize: 14,
                              borderColor: p.isDark ? const Color(0xFF5B1D1D) : const Color(0xFFFECACA),
                              foreground: _connected ? p.danger : p.faint,
                              onPressed: _connected ? _disconnect : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(header: true, child: Text('Health platforms', style: VnText.heading(17, weight: FontWeight.w700, color: p.ink))),
                const SizedBox(height: 18),
                VnListGroup(
                  children: [
                    VnListRow(
                      leading: const VnIconTile(icon: Icons.favorite_border_rounded, bg: Color(0xFFD1FAE5), fg: Color(0xFF047857), size: 40),
                      title: 'Health Connect',
                      subtitle: _isAndroid
                          ? (_connected ? 'Android · ${_syncedKeys.length} data types shared' : 'Android · not connected')
                          : 'Android only',
                      chevron: false,
                      trailing: VnSwitch(
                        value: _isAndroid && _connected,
                        semanticLabel: 'Health Connect',
                        onChanged: _isAndroid ? (v) => v ? _syncDevice() : _disconnect() : null,
                      ),
                    ),
                    VnListRow(
                      leading: const VnIconTile(icon: Icons.favorite_border_rounded, bg: Color(0xFFFFE4E6), fg: Color(0xFFBE123C), size: 40),
                      title: 'Apple Health',
                      subtitle: _isIos
                          ? (_connected ? 'iPhone · ${_syncedKeys.length} data types shared' : 'iPhone · not connected')
                          : 'iPhone only',
                      chevron: false,
                      trailing: VnSwitch(
                        value: _isIos && _connected,
                        semanticLabel: 'Apple Health',
                        onChanged: _isIos ? (v) => v ? _syncDevice() : _disconnect() : null,
                      ),
                    ),
                    VnListRow(
                      leading: const VnIconTile(icon: Icons.bluetooth_rounded, bg: Color(0xFFE0F2FE), fg: Color(0xFF0369A1), size: 40),
                      title: 'Bluetooth BP cuff',
                      subtitle: 'Omron, Withings and more',
                      chevron: false,
                      trailing: VnLink(label: 'Pair', fontSize: 13, weight: FontWeight.w700, onTap: _pairCuff),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Semantics(header: true, child: Text('What VitaNet can read', style: VnText.heading(17, weight: FontWeight.w700, color: p.ink))),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = (c.maxWidth - 8) / 2;
                    const types = [
                      ('Heart rate', true),
                      ('Blood oxygen', true),
                      ('Temperature', true),
                      ('Blood pressure', true),
                      ('Sleep', true),
                      ('Steps', true),
                      ('Breathing rate', true),
                      ('Menstrual cycle', false),
                    ];
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in types) SizedBox(width: w, child: _ReadType(label: t.$1, enabled: t.$2)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: p.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'VitaNet only reads these types, with your permission. Data stays on your device and is only sent when you start a check.',
                        style: VnText.body(12, color: p.muted, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadType extends StatelessWidget {
  final String label;
  final bool enabled;
  const _ReadType({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final p = VnPalette.of(context);
    return Semantics(
      checked: enabled,
      label: enabled ? '$label, read by VitaNet' : '$label, not read',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Icon(enabled ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 20, color: enabled ? p.brand : p.faint),
            const SizedBox(width: 10),
            Flexible(child: Text(label, style: VnText.body(14, weight: FontWeight.w500, color: enabled ? p.ink : p.muted))),
          ],
        ),
      ),
    );
  }
}
