import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/vitals_sync.dart';
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
    // Connected = sharing is on AND readings were really read this session (not just "a permission exists").
    final vitals = ref.read(liveVitalsProvider);
    final outcome = ref.read(lastSyncOutcomeProvider);
    if (ref.read(deviceSharingProvider) && vitals.isNotEmpty && (outcome == null || outcome.read > 0)) {
      _connected = true;
      _lastSync = ref.read(vitalsLastSyncProvider);
      _syncedKeys.addAll(vitals.keys);
    }
  }

  /// Connect / Sync now. Each step is reported as it really went (audit F-06): permission, reading the
  /// watch data, saving it to the VitaNet account. Only a real read counts as "connected".
  Future<void> _syncDevice() async {
    setState(() => _isSyncing = true);
    await ref.read(deviceSharingProvider.notifier).set(true);
    final hasPermissions = await ref.read(healthServiceProvider).requestPermissions();
    SyncOutcome? outcome;
    if (hasPermissions) {
      ref.read(lastSyncOutcomeProvider.notifier).state = null;
      try {
        await ref.read(vitalsSyncProvider).syncNow();
      } catch (e) {
        debugPrint('Device sync failed: $e');
      }
      outcome = ref.read(lastSyncOutcomeProvider);
    }
    if (!mounted) return;
    final read = outcome?.read ?? 0;
    final uploaded = outcome?.uploaded ?? 0;
    final readWorked = hasPermissions && outcome != null && (read > 0 || outcome.error == null);
    final String message;
    if (!hasPermissions) {
      message = 'Could not get $_platformName permission. Install it or check its settings.';
    } else if (outcome == null) {
      message = 'Sign in first, then sync again.';
    } else if (read > 0 && uploaded > 0) {
      message = 'Synced $read readings from $_platformName and saved them to your VitaNet account.';
    } else if (read > 0) {
      message = 'Read $read readings on this phone, but could not save them to your account. '
          'They will be sent at the next sync.';
    } else if (outcome.error == null) {
      message = 'Connected. No readings from the last 2 days yet.';
    } else {
      message = 'Permission is granted, but the readings could not be read ($_platformName said: ${outcome.error}).';
    }
    setState(() {
      _isSyncing = false;
      _connected = readWorked;
      if (readWorked) {
        _lastSync = outcome!.at;
        _syncedKeys.addAll(ref.read(liveVitalsProvider).keys);
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
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
    // Stop using the device's readings everywhere (audit F-05): no more syncing (remembered after restart),
    // and the readings already shown on the dashboard and given to triage are cleared.
    await ref.read(deviceSharingProvider.notifier).set(false);
    ref.read(liveVitalsProvider.notifier).clear();
    ref.read(vitalsLastSyncProvider.notifier).state = null;
    ref.read(lastSyncOutcomeProvider.notifier).state = null;
    if (!mounted) return;
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
              physics: const VnAlwaysScrollablePhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                VnTopBar(title: 'Devices & data', onBack: _back),
                const SizedBox(height: 18),
                VnCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: const SizedBox(
                              width: 60,
                              height: 60,
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
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (label, bg, fg) in chips)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: p.tintBg(bg, fg),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(label,
                                    style: VnText.body(13, weight: FontWeight.w600, color: p.tintFg(fg))),
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
                              height: 40,
                              radius: 8,
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
                              height: 40,
                              radius: 8,
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
                const SizedBox(height: 14),
                VnListGroup(
                  children: [
                    VnListRow(
                      leading: const VnIconTile(icon: Icons.favorite_border_rounded, bg: Color(0xFFDCFCE7), fg: Color(0xFF15803D), size: 44),
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
                      leading: const VnIconTile(icon: Icons.favorite_border_rounded, bg: Color(0xFFFFE4E6), fg: Color(0xFFBE123C), size: 44),
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
                      leading: const VnIconTile(icon: Icons.bluetooth_rounded, bg: Color(0xFFE0F2FE), fg: Color(0xFF0369A1), size: 44),
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
