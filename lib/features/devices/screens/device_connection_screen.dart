import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceConnectionScreen extends ConsumerStatefulWidget {
  final String metricId;

  const DeviceConnectionScreen({super.key, required this.metricId});

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends ConsumerState<DeviceConnectionScreen> {
  bool _isConnecting = false;

  void _syncDevice() async {
    setState(() => _isConnecting = true);
    
    final service = ref.read(healthServiceProvider);
    bool hasPermissions = await service.requestPermissions();
    
    if (hasPermissions) {
      try {
        final biometrics = await service.fetchBiometrics();
        if (biometrics.isNotEmpty && mounted) {
          biometrics.forEach((key, value) {
            final doubleVal = double.tryParse(value.toString());
            if (doubleVal != null) {
              ref.read(liveVitalsProvider.notifier).setVital(key, doubleVal);
            }
          });
        }
      } catch (e) {
        debugPrint('Error fetching immediate biometrics: $e');
      }
    }

    if (mounted) {
      setState(() => _isConnecting = false);
      if (hasPermissions) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully synced with Health Connect!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not obtain Health Connect permissions. Please install it or check settings.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openHealthConnectSettings() async {
    final Uri url = Uri.parse('market://details?id=com.google.android.apps.healthdata');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final Uri webUrl = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch Health Connect: $e');
    }
  }

  String _getDeviceName() {
    switch (widget.metricId) {
      case 'heart_rate':
        return 'Heart Rate';
      case 'blood_oxygen':
        return 'Blood Oxygen';
      case 'temperature':
        return 'Body Temperature';
      case 'respiratory_rate':
        return 'Respiratory Rate';
      default:
        return 'Health Data';
    }
  }

  Color _getDeviceColor() {
    switch (widget.metricId) {
      case 'heart_rate':
        return const Color(0xFFEC4899);
      case 'blood_oxygen':
        return const Color(0xFF8B5CF6);
      case 'temperature':
        return const Color(0xFF3B82F6);
      case 'respiratory_rate':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Device Setup',
          style: TextStyle(
            color: context.isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 80,
                  color: _getDeviceColor(),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Sync your ${_getDeviceName()} Data',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'VitaNet reads your real-time vitals through Health Connect. Follow these quick steps to link your smartwatch or fitness tracker:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.isDark ? Colors.white70 : Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                _buildStep(
                  context,
                  number: '1',
                  title: 'Install Health Connect (if missing)',
                  description:
                      'Tap the button below to ensure Google Health Connect is installed on your phone.',
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildStep(
                  context,
                  number: '2',
                  title: 'Link Your Watch App',
                  description:
                      "Open your watch's official app (e.g., Fitbit, Garmin, Samsung Health) and turn on \"Share with Health Connect\" in its settings.",
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildStep(
                  context,
                  number: '3',
                  title: 'Start Syncing!',
                  description:
                      'Tap "Sync Data Now" to grant VitaNet permission to read your vitals securely.',
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isConnecting ? null : _syncDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getDeviceColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Sync Data Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _openHealthConnectSettings,
                  icon: const Icon(Icons.settings_applications_rounded),
                  label: const Text('Open Health Connect / Play Store'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.isDark ? Colors.white70 : Colors.black87,
                    side: BorderSide(
                      color: context.isDark ? Colors.white24 : Colors.black12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, {required String number, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _getDeviceColor().withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: _getDeviceColor(),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: context.isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
